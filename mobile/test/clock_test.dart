import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/core/clock.dart';

void main() {
  tearDown(() => debugSchoolClock = null);

  test('schoolNow is Indian time (UTC+5:30) whatever the phone time zone is', () {
    final s = schoolNow();
    final expected = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final asUtc = DateTime.utc(s.year, s.month, s.day, s.hour, s.minute, s.second);
    expect(asUtc.difference(expected).inSeconds.abs() < 5, true);
  });

  test('the clock can be frozen for tests', () {
    debugSchoolClock = () => DateTime(2026, 11, 7, 23, 50);
    expect(schoolNow(), DateTime(2026, 11, 7, 23, 50));
  });
}
