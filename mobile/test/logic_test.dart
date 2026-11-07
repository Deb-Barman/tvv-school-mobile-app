import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/core/api_exception.dart';
import 'package:tvv_mobile/data/attendance_stats.dart';
import 'package:tvv_mobile/data/models/academics.dart';
import 'package:tvv_mobile/ui/format.dart';

AttendanceRecord _rec(int d, AttendanceStatus s) => AttendanceRecord(id: '$d', studentId: 's', date: DateTime(2026, 11, d), status: s);

void main() {
  group('AttendanceSummary', () {
    final five = [for (var i = 1; i <= 5; i++) _rec(i, i <= 4 ? AttendanceStatus.present : AttendanceStatus.absent)];

    test('counts and labels use the working days of the session', () {
      final s = AttendanceSummary.of(five, workingDays: 200, minPercent: 75);
      expect(s.present, 4);
      expect(s.absent, 1);
      expect(s.countLabel, '4 of 200');
      expect(s.percentOfMarked, closeTo(80, 1e-9));
      expect(s.ringPercent, closeTo(2, 1e-9));
      expect(s.tone, 'good');
    });

    test('falls back to present-of-marked without working days', () {
      final s = AttendanceSummary.of(five, minPercent: 75);
      expect(s.countLabel, '4 of 5');
      expect(s.ringPercent, closeTo(80, 1e-9));
    });

    test('tone bands: good >= min, warn >= min-15, otherwise bad', () {
      AttendanceSummary mk(int p, int a) => AttendanceSummary(present: p, absent: a, minPercent: 75);
      expect(mk(3, 1).tone, 'good'); // 75%
      expect(mk(3, 2).tone, 'warn'); // 60%
      expect(mk(1, 1).tone, 'bad'); // 50%
      expect(mk(0, 0).tone, 'accent'); // no data
    });
  });

  group('ResultGroup', () {
    ResultRow row(String sess, String term, double m) =>
        ResultRow(id: '$sess$term$m', studentId: 's', subjectId: 'x', sessionId: sess, term: term, marks: m, fullMarks: 100);

    test('groups by session and term, newest first, with totals', () {
      final sessions = [AcademicSession(id: 'old', label: '2025'), AcademicSession(id: 'cur', label: '2026', isCurrent: true)];
      final g = ResultGroup.group([row('old', 'SEM1', 50), row('cur', 'SEM1', 80), row('cur', 'SEM2', 90), row('cur', 'SEM2', 70)],
          sessions: sessions);
      expect(g.length, 3);
      expect(g.first.sessionId, 'cur');
      expect(g.first.term, 'SEM2');
      expect(g.first.total, 160);
      expect(g.first.percent, closeTo(80, 1e-9));
    });
  });

  group('formatters', () {
    test('12-hour time', () {
      expect(fmtTime('10:00:00'), '10:00 AM');
      expect(fmtTime('00:05'), '12:05 AM');
      expect(fmtTime('13:45:00'), '1:45 PM');
      expect(fmtTime('12:00'), '12:00 PM');
    });
    test('dates and marks', () {
      expect(fmtDate(DateTime(2026, 11, 5)), '5 Nov 2026');
      expect(marks(91), '91');
      expect(marks(41.5), '41.5');
    });
  });

  group('ApiException', () {
    test('keeps per-field messages and builds a readable summary', () {
      final e = ApiException.fromResponse(400, {
        'username': ['A user with that username already exists.']
      });
      expect(e.kind, ApiErrorKind.validation);
      expect(e.fieldErrors['username'], 'A user with that username already exists.');
      expect(e.message, startsWith('Username:'));
    });
    test('maps statuses to kinds', () {
      expect(ApiException.fromResponse(401, null).kind, ApiErrorKind.unauthorized);
      expect(ApiException.fromResponse(403, {'detail': 'No.'}).message, 'No.');
      expect(ApiException.fromResponse(429, null).kind, ApiErrorKind.throttled);
      expect(ApiException.fromResponse(503, null).kind, ApiErrorKind.server);
    });
  });
}
