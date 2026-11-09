import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/core/update_checker.dart';
import 'package:tvv_mobile/data/attendance_stats.dart';
import 'package:tvv_mobile/data/models/academics.dart';
import 'package:tvv_mobile/data/next_period.dart';
import 'package:tvv_mobile/data/results_stats.dart';

AttendanceRecord rec(int d, bool p, {int month = 10}) =>
    AttendanceRecord(id: '$month-$d', studentId: 's', date: DateTime(2026, month, d), status: p ? AttendanceStatus.present : AttendanceStatus.absent);

void main() {
  test('attendance insights: spare days, streaks, monthly chart', () {

  // 10 marked: 8 present, 2 absent, session of 200 working days, min 75
  final recs = [for (var d = 1; d <= 8; d++) rec(d, true), rec(9, false), rec(10, false)];
  final i = AttendanceInsights(recs, workingDays: 200, minPercent: 75);
  expect(i.present == 8 && i.absent == 2 && i.marked == 10, isTrue, reason: 'counts');
  expect(i.remaining == 190, isTrue, reason: 'remaining');
  expect(i.requiredPresent == 150, isTrue, reason: 'required present 75% of 200');
  expect(i.spareAbsences == 8 + 190 - 150, isTrue, reason: 'spare absences = 48');
  expect((i.bestPossiblePercent! - 99.0).abs() < 1e-9, isTrue, reason: 'best possible 99%');
  // impossible case: 60 absent of 100 marked, session 100
  final bad = AttendanceInsights([for (var d = 1; d <= 28; d++) rec(d, d > 15)], workingDays: 28, minPercent: 75);
  expect(bad.spareAbsences! < 0, isTrue, reason: 'cannot reach minimum -> negative');
  // unknown working days
  final u = AttendanceInsights([rec(1, true), rec(2, false), rec(3, false), rec(4, true)], minPercent: 75);
  expect(u.spareAbsences == null && u.remaining == null, isTrue, reason: 'unknown session');
  expect(u.presentDaysNeeded == 4, isTrue, reason: '2/4 -> need 4 present in a row to reach 75% (6/8)');
  expect(AttendanceInsights([rec(1, true), rec(2, true)]).presentDaysNeeded == 0, isTrue, reason: 'already above');
  expect(AttendanceInsights([rec(1, true), rec(2, false)], minPercent: 100).presentDaysNeeded == -1, isTrue, reason: 'impossible at 100%');
  // streaks
  final s = AttendanceInsights([rec(1, true), rec(2, true), rec(3, true), rec(4, false), rec(5, true), rec(6, true)]);
  expect(s.currentStreak == 2 && s.bestStreak == 3, isTrue, reason: 'streaks');
  // monthly
  final m = AttendanceInsights([rec(1, true, month: 9), rec(2, false, month: 9), rec(3, true, month: 10)]).monthly(DateTime(2026, 10, 15), months: 3);
  expect(m.length == 3 && m[0].month == 8 && m[1].month == 9 && m[2].month == 10, isTrue, reason: 'month order');
  expect(m[0].percent == null && m[1].percent == 50 && m[2].percent == 100, isTrue, reason: 'month percents');
  // year wrap
  expect(AttendanceInsights([]).monthly(DateTime(2026, 2, 1), months: 3).map((e) => e.month).toList().join(',') == '12,1,2', isTrue, reason: 'wraps over new year');

  });

  test('results overview: overall, best / weakest, changes since the previous term', () {
  ResultRow row(String sub, double m, String term, {String ses = 'a'}) => ResultRow(id: '$sub$term', studentId: 's', subjectId: sub, sessionId: ses, term: term, marks: m, fullMarks: 100);
  final sessions = [const AcademicSession(id: 'a', label: '2025-26')];
  final groups = ResultGroup.group([row('eng', 50, 'SEM1'), row('ban', 70, 'SEM1'), row('eng', 65, 'SEM2'), row('ban', 60, 'SEM2'), row('py', 90, 'SEM2')], sessions: sessions);
  final o = ResultsOverview(groups);
  expect(o.chronological.first.term == 'SEM1' && o.chronological.last.term == 'SEM2', isTrue, reason: 'chronological order');
  expect((o.overallPercent - 335 / 5).abs() < 1e-9, isTrue, reason: 'overall percent');
  expect(o.best!.subjectId == 'py' && o.weakest!.subjectId == 'eng', isTrue, reason: 'best / weakest');
  expect(o.termDelta(0) == null && (o.termDelta(1)! - (71.666666666 - 60)).abs() < 1e-3, isTrue, reason: 'term delta');
  expect(o.subjectDelta(1, 'eng') == 15 && o.subjectDelta(1, 'ban') == -10 && o.subjectDelta(1, 'py') == null, isTrue, reason: 'subject deltas');
  expect(ResultsOverview([]).overallPercent == 0, isTrue, reason: 'empty results');

  });

  test('next period and time helpers', () {
  const slots = [PeriodSlot(startMin: 600, endMin: 645, title: 'Maths'), PeriodSlot(startMin: 645, endMin: 660, title: 'Break', isBreak: true), PeriodSlot(startMin: 660, endMin: 705, title: 'Physics')];
  expect(nextPeriod(slots, 590)!.live == false && nextPeriod(slots, 590)!.minutes == 10 && nextPeriod(slots, 590)!.slot.title == 'Maths', isTrue, reason: 'before school');
  expect(nextPeriod(slots, 620)!.live && nextPeriod(slots, 620)!.minutes == 25, isTrue, reason: 'live period');
  expect(nextPeriod(slots, 650)!.slot.title == 'Physics' && nextPeriod(slots, 650)!.minutes == 10, isTrue, reason: 'break -> next is physics');
  expect(nextPeriod(slots, 705) == null, isTrue, reason: 'day over');
  expect(minutesOfDay('09:30:00') == 570 && minutesOfDay('7:05') == 425, isTrue, reason: 'minutesOfDay');
  expect(minutesLabel(25) == '25 min' && minutesLabel(65) == '1 h 5 min' && minutesLabel(120) == '2 h', isTrue, reason: 'minutesLabel');

  });

  test('update checker reads the release page', () {
  final info = UpdateChecker.parseRelease({'body': 'Latest\n<!-- tvv-build:57 tvv-version:1.3.0 -->', 'html_url': 'https://x/r', 'assets': [{'browser_download_url': 'https://x/TVV-School.apk'}]});
  expect(info != null && info.build == 57 && info.version == '1.3.0' && info.downloadUrl == 'https://x/TVV-School.apk', isTrue, reason: 'parse release');
  expect(UpdateChecker.parseRelease({'body': 'no marker'}) == null && UpdateChecker.parseRelease('x') == null, isTrue, reason: 'bad release ignored');

  });
}
