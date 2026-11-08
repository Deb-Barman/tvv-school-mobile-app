/// Where the last good answer of every GET request is kept, so the app can still show yesterday's timetable,
/// notices or attendance when there is no signal. Pure Dart: the phone implementation lives in
/// `state/prefs_response_cache.dart`.
///
/// Privacy rule: the whole cache is wiped whenever a session starts or ends (see ApiClient), so one person's
/// saved data can never be shown to the next person who signs in on the same phone.
abstract class ResponseCache {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> clear();
}

class MemoryResponseCache implements ResponseCache {
  final Map<String, String> _data = {};

  int get length => _data.length;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> clear() async => _data.clear();
}
