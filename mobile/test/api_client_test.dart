import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/core/api_client.dart';
import 'package:tvv_mobile/core/api_exception.dart';
import 'package:tvv_mobile/core/token_store.dart';

void main() {
  late HttpServer server;
  var hits = 0;
  var refreshCalls = 0;

  setUp(() async {
    hits = 0;
    refreshCalls = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      hits++;
      final path = req.uri.path;
      req.response.headers.contentType = ContentType.json;
      if (path.endsWith('/flaky/') && hits <= 2) {
        req.response.statusCode = 503;
      } else if (path.endsWith('/auth/token/refresh/')) {
        refreshCalls++;
        req.response.write(jsonEncode({'access': 'new-access', 'refresh': 'new-refresh'}));
      } else if (path.endsWith('/secret/')) {
        final ok = req.headers.value('authorization') == 'Bearer new-access';
        req.response.statusCode = ok ? 200 : 401;
        req.response.write(jsonEncode(ok ? {'ok': true} : {'detail': 'expired'}));
      } else {
        req.response.write(jsonEncode({'ok': true}));
      }
      await req.response.close();
    });
  });

  tearDown(() async => server.close(force: true));

  ApiClient client(MemoryTokenStore store) => ApiClient(
      baseUrl: 'http://127.0.0.1:${server.port}/api',
      tokens: store,
      retryDelays: const [Duration(milliseconds: 10), Duration(milliseconds: 10)]);

  test('GET retries through 503 (server waking up)', () async {
    final api = client(MemoryTokenStore());
    final r = await api.getMap('/flaky/', auth: false);
    expect(r['ok'], true);
    expect(hits, 3);
  });

  test('expired access token is refreshed once and the rotated refresh token is stored', () async {
    final store = MemoryTokenStore()
      ..access = 'old'
      ..refresh = 'old-refresh';
    final api = client(store);
    final results = await Future.wait([for (var i = 0; i < 4; i++) api.getMap('/secret/')]);
    expect(results.every((r) => r['ok'] == true), true);
    expect(refreshCalls, 1); // single flight
    expect(store.refresh, 'new-refresh');
  });

  test('unreachable server becomes a friendly network error', () async {
    final dead = ApiClient(baseUrl: 'http://127.0.0.1:1/api', tokens: MemoryTokenStore(), retryDelays: const []);
    expect(() => dead.getMap('/x/', auth: false), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
  });
}
