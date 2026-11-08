import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvv_mobile/state/prefs_response_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('saved answers can be read back, the oldest are dropped, and clear removes everything', () async {
    final cache = PrefsResponseCache();
    await cache.write('/a/', '{"n":1}');
    expect(await cache.read('/a/'), '{"n":1}');
    expect(await cache.read('/missing/'), isNull);

    for (var i = 0; i < 70; i++) {
      await cache.write('/k$i/', '$i');
    }
    expect(await cache.read('/a/'), isNull); // dropped: only the newest 60 are kept
    expect(await cache.read('/k0/'), isNull);
    expect(await cache.read('/k69/'), '69');

    await cache.clear();
    expect(await cache.read('/k69/'), isNull);
  });
}
