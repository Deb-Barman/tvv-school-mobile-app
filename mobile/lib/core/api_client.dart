import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_exception.dart';
import 'json.dart';
import 'response_cache.dart';
import 'token_store.dart';

enum _RefreshOutcome { ok, sessionOver, transient }

class _Cached {
  _Cached(this.value);
  final Object? value;
}

class _Raw {
  _Raw(this.status, this.json);
  final int status;
  final Object? json;
}

/// HTTP client for the school's Django REST API (JWT, Bearer scheme).
///
/// Behaviours that matter on a school phone:
///  * Access tokens live 15 minutes. A 401 triggers ONE refresh, shared by every request that
///    failed at the same moment ("single flight"), then the request is repeated.
///  * Refresh tokens ROTATE on this backend: every refresh returns a new refresh token and
///    blacklists the old one, so the new one is always stored.
///  * A refresh that fails because the server is asleep/busy/offline does NOT sign the person
///    out; only a definite "token no longer valid" answer does ([onSessionExpired]).
///  * Reads (GET) are retried a few times on network errors and 502/503/504, because the free
///    Render server takes ~30-60 s to wake up.
///  * Uses only dart:io, so nothing but the platform's own TLS stack is involved.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokens,
    this.onSessionExpired,
    this.cache,
    HttpClient? httpClient,
    this.retryDelays = const [Duration(milliseconds: 1500), Duration(milliseconds: 3500), Duration(milliseconds: 7000)],
    this.getTimeout = const Duration(seconds: 25),
    this.writeTimeout = const Duration(seconds: 40),
  })  : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _http = httpClient ?? _defaultClient();

  final String baseUrl;
  final TokenStore tokens;
  final HttpClient _http;
  final List<Duration> retryDelays;
  final Duration getTimeout;
  final Duration writeTimeout;

  /// Called once when the server says the sign-in is definitely over (expired / password changed / disabled).
  void Function()? onSessionExpired;

  /// Last good answer of every GET. When the network is down (or the free server is asleep for too long) the saved
  /// copy is returned instead of an error, and [onOfflineData] is told so the screen can say "showing saved data".
  final ResponseCache? cache;

  /// true = the last read came from the saved copy; false = it came live from the server.
  void Function(bool offline)? onOfflineData;
  bool _offline = false;

  void _setOffline(bool v) {
    if (_offline == v) return;
    _offline = v;
    onOfflineData?.call(v);
  }

  String? _access;
  String? _refresh;
  bool _loaded = false;
  Future<_RefreshOutcome>? _refreshInFlight;

  static HttpClient _defaultClient() {
    final c = HttpClient();
    c.connectionTimeout = const Duration(seconds: 20);
    c.userAgent = 'TVV-Mobile/1.3';
    return c;
  }

  // ---------------------------------------------------------------- session

  Future<void> _load() async {
    if (_loaded) return;
    _access = await tokens.readAccess();
    _refresh = await tokens.readRefresh();
    _loaded = true;
  }

  Future<bool> hasSession() async {
    await _load();
    return _refresh != null && _refresh!.isNotEmpty;
  }

  Future<void> setSession({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    await _wipeCache(); // a new sign-in always starts from an empty cache
    await tokens.save(access: access, refresh: refresh);
  }

  Future<void> clearSession() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _wipeCache(); // nobody else may see the previous person's saved data
    _setOffline(false);
    await tokens.clear();
  }

  /// Blacklists the refresh token on the server (best effort) and forgets the session locally.
  Future<void> signOut() async {
    await _load();
    final refresh = _refresh;
    await clearSession();
    if (refresh == null) return;
    try {
      await _raw('POST', '/auth/logout/', body: {'refresh': refresh}, token: null, timeout: const Duration(seconds: 8));
    } catch (_) {
      // Signing out must always work locally, even offline.
    }
  }

  /// Wakes a sleeping free-tier server so the first real request is fast. Never throws.
  Future<void> warmUp() async {
    try {
      await _raw('GET', '/health/', token: null, timeout: const Duration(seconds: 60));
    } catch (_) {}
  }

  void close() => _http.close(force: true);

  // ---------------------------------------------------------------- requests

  Future<Json> getMap(String path, {Map<String, Object?>? query, bool auth = true}) async =>
      asJson(await request('GET', path, query: query, auth: auth));

  Future<Object?> getRaw(String path, {Map<String, Object?>? query, bool auth = true}) => request('GET', path, query: query, auth: auth);

  Future<Json> post(String path, [Object? body, bool auth = true, bool retryable = false]) async =>
      asJson(await request('POST', path, body: body ?? <String, Object?>{}, auth: auth, retryable: retryable));

  Future<Json> patch(String path, Object body) async => asJson(await request('PATCH', path, body: body));

  Future<void> delete(String path) async {
    await request('DELETE', path);
  }

  /// Every row of a paginated DRF list (follows page numbers itself; `next` links are ignored on
  /// purpose because behind a proxy they can carry the wrong scheme). Also accepts a plain JSON array.
  Future<List<Json>> listAll(String path, {Map<String, Object?>? query, int pageSize = 200, int maxPages = 25, bool auth = true}) async {
    final out = <Json>[];
    for (var page = 1; page <= maxPages; page++) {
      final q = <String, Object?>{...?query, 'page': page, 'page_size': pageSize};
      final raw = await request('GET', path, query: q, auth: auth);
      if (raw is List) return asJsonList(raw);
      final data = asJson(raw);
      final rows = asJsonList(data['results']);
      out.addAll(rows);
      if (data['next'] == null || rows.isEmpty) break;
    }
    return out;
  }

  /// `count` of a paginated list without downloading the rows.
  Future<int> count(String path, {Map<String, Object?>? query}) async {
    final data = asJson(await request('GET', path, query: {...?query, 'page_size': 1}));
    return intOr(data, 'count');
  }

  /// Core request loop. Returns the decoded JSON body (or null for 204 / empty).
  Future<Object?> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool auth = true,
    bool retryable = false,
  }) async {
    await _load();
    final isGet = method == 'GET';
    final canRetry = isGet || retryable;
    final timeout = isGet ? getTimeout : writeTimeout;
    var refreshed = false;
    var attempt = 0;

    // A saved copy (if any) lets a read give up sooner instead of making someone wait through every retry.
    final cacheKey = (isGet && auth && cache != null) ? _cacheKey(path, query) : null;
    final cached = cacheKey == null ? null : await _cacheRead(cacheKey);
    final maxRetries = (cached != null && retryDelays.length > 1) ? 1 : retryDelays.length;

    while (true) {
      _Raw res;
      try {
        res = await _raw(method, path, query: query, body: body, token: auth ? _access : null, timeout: timeout);
      } on ApiException catch (e) {
        if (canRetry && attempt < maxRetries) {
          await Future<void>.delayed(retryDelays[attempt++]);
          continue;
        }
        if (cached != null && e.isNetwork) {
          _setOffline(true);
          return cached.value;
        }
        rethrow;
      }

      if (res.status == 401 && auth) {
        if (!refreshed) {
          refreshed = true;
          final outcome = await _refreshTokens();
          if (outcome == _RefreshOutcome.ok) continue;
          if (outcome == _RefreshOutcome.sessionOver) {
            onSessionExpired?.call();
            throw ApiException.fromResponse(401, null);
          }
          throw ApiException.network('Couldn\u2019t reconnect to the school server. Please try again.');
        }
        // A brand-new token was refused too (account disabled, password changed...).
        await clearSession();
        onSessionExpired?.call();
        throw ApiException.fromResponse(401, res.json);
      }

      final waking = res.status == 502 || res.status == 503 || res.status == 504;
      if (canRetry && waking && attempt < maxRetries) {
        await Future<void>.delayed(retryDelays[attempt++]);
        continue;
      }
      if (cached != null && waking) {
        _setOffline(true);
        return cached.value;
      }

      if (res.status >= 200 && res.status < 300) {
        if (isGet) {
          _setOffline(false);
          if (cacheKey != null) unawaited(_cacheWrite(cacheKey, res.json));
        }
        return res.json;
      }
      throw ApiException.fromResponse(res.status, res.json);
    }
  }

  // ---------------------------------------------------------------- internals

  String _cacheKey(String path, Map<String, Object?>? query) {
    final u = _uri(path, query).toString();
    return u.startsWith(baseUrl) ? u.substring(baseUrl.length) : u;
  }

  Future<_Cached?> _cacheRead(String key) async {
    try {
      final s = await cache!.read(key);
      if (s == null) return null;
      return _Cached(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheWrite(String key, Object? json) async {
    if (json == null) return;
    try {
      final s = jsonEncode(json);
      if (s.length > 180000) return; // keep the phone's preferences file small
      await cache!.write(key, s);
    } catch (_) {}
  }

  Future<void> _wipeCache() async {
    try {
      await cache?.clear();
    } catch (_) {}
  }

  Future<_RefreshOutcome> _refreshTokens() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<_RefreshOutcome> _doRefresh() async {
    await _load();
    final refresh = _refresh;
    if (refresh == null || refresh.isEmpty) return _RefreshOutcome.sessionOver;
    try {
      final res = await _raw('POST', '/auth/token/refresh/', body: {'refresh': refresh}, token: null, timeout: writeTimeout);
      if (res.status == 200) {
        final map = asJson(res.json);
        final access = map['access'];
        if (access is! String || access.isEmpty) return _RefreshOutcome.transient;
        final rotated = map['refresh'];
        _access = access;
        if (rotated is String && rotated.isNotEmpty) _refresh = rotated;
        await tokens.save(access: access, refresh: rotated is String && rotated.isNotEmpty ? rotated : null);
        return _RefreshOutcome.ok;
      }
      if (res.status == 400 || res.status == 401 || res.status == 403) {
        await clearSession();
        return _RefreshOutcome.sessionOver;
      }
      return _RefreshOutcome.transient; // 429 / 5xx / proxy hiccup: not the person's fault
    } on ApiException {
      return _RefreshOutcome.transient;
    }
  }

  Uri _uri(String path, Map<String, Object?>? query) {
    final base = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return base;
    final params = <String, String>{};
    query.forEach((k, v) {
      if (v == null) return;
      final s = v is bool ? (v ? '1' : '0') : '$v';
      if (s.isEmpty) return;
      params[k] = s;
    });
    return params.isEmpty ? base : base.replace(queryParameters: params);
  }

  Future<_Raw> _raw(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    required String? token,
    required Duration timeout,
  }) async {
    final uri = _uri(path, query);
    try {
      return await _exchange(method, uri, body, token).timeout(timeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } on IOException {
      throw ApiException.network();
    }
  }

  Future<_Raw> _exchange(String method, Uri uri, Object? body, String? token) async {
    final req = await _http.openUrl(method, uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      req.headers.contentType = ContentType.json;
      req.contentLength = bytes.length;
      req.add(bytes);
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    Object? decoded;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        decoded = null; // an HTML error page from a proxy, for example
      }
    }
    return _Raw(res.statusCode, decoded);
  }
}
