import 'package:shared_preferences/shared_preferences.dart';

import '../core/response_cache.dart';

/// Saved copies of GET answers, kept in the phone's preferences (no secrets: tokens live in the Keystore/Keychain).
/// At most [_maxEntries] answers are kept; the oldest is dropped first. Every failure is swallowed on purpose:
/// the cache is a convenience and must never break the app.
class PrefsResponseCache implements ResponseCache {
  static const _prefix = 'tvv_cache:';
  static const _indexKey = 'tvv_cache_index';
  static const _maxEntries = 60;

  // Parallel requests finish at the same moment; their cache writes run one after another so the index stays correct.
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final next = _tail.then((_) => job());
    _tail = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> read(String key) async {
    final p = await _prefs();
    return p?.getString('$_prefix$key');
  }

  @override
  Future<void> write(String key, String value) => _serial(() async {
        final p = await _prefs();
        if (p == null) return;
        try {
          final index = List<String>.of(p.getStringList(_indexKey) ?? const <String>[]);
          index.remove(key);
          index.add(key);
          while (index.length > _maxEntries) {
            await p.remove('$_prefix${index.removeAt(0)}');
          }
          await p.setString('$_prefix$key', value);
          await p.setStringList(_indexKey, index);
        } catch (_) {}
      });

  @override
  Future<void> clear() => _serial(() async {
        final p = await _prefs();
        if (p == null) return;
        try {
          // Look at the real keys, not only the index, so nothing can be left behind.
          for (final k in p.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
            await p.remove(k);
          }
          await p.remove(_indexKey);
        } catch (_) {}
      });
}
