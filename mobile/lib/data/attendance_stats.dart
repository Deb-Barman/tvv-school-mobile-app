import 'models/academics.dart';

/// Attendance numbers for one person, computed the same way the website does it.
///
/// Students and teachers cannot call the Super Admin report endpoint, so the app works the figures
/// out from their own rows: "present out of the session's working days" (e.g. 5 of 200) plus the
/// percentage of the days that have actually been marked so far.
class AttendanceSummary {
  const AttendanceSummary({required this.present, required this.absent, this.workingDays, this.minPercent = 75});

  final int present;
  final int absent;
  final int? workingDays;
  final int minPercent;

  int get marked => present + absent;

  /// Present / marked days (what "my attendance so far" means).
  double? get percentOfMarked => marked == 0 ? null : present / marked * 100;

  /// Present / working days of the whole session.
  double? get percentOfSession =>
      (workingDays == null || workingDays! <= 0) ? null : (present / workingDays! * 100).clamp(0, 100).toDouble();

  /// What the ring shows.
  double get ringPercent => percentOfSession ?? percentOfMarked ?? 0;

  String get ringLabel => '${ringPercent.toStringAsFixed(ringPercent >= 10 || ringPercent == 0 ? 0 : 1)}%';

  /// "5 of 200" (or "5 of 8 days" when the session has no working-day total).
  String get countLabel => workingDays != null && workingDays! > 0 ? '$present of $workingDays' : '$present of $marked';

  /// 'good' / 'warn' / 'bad' by the SO FAR percentage against the session's minimum.
  String get tone {
    final p = percentOfMarked;
    if (p == null) return 'accent';
    if (p >= minPercent) return 'good';
    if (p >= minPercent - 15) return 'warn';
    return 'bad';
  }

  static AttendanceSummary of(Iterable<AttendanceRecord> records, {int? workingDays, int minPercent = 75}) {
    var p = 0, a = 0;
    for (final r in records) {
      if (r.status == AttendanceStatus.present) {
        p++;
      } else {
        a++;
      }
    }
    return AttendanceSummary(present: p, absent: a, workingDays: workingDays, minPercent: minPercent);
  }
}

/// Results of one student grouped for display: session -> term -> rows, with totals.
class ResultGroup {
  ResultGroup({required this.sessionId, required this.term, required this.rows});

  final String sessionId;
  final String term;
  final List<ResultRow> rows;

  double get total => rows.fold(0.0, (a, r) => a + r.marks);
  double get fullTotal => rows.fold(0.0, (a, r) => a + r.fullMarks);
  double get percent => fullTotal <= 0 ? 0 : total / fullTotal * 100;
  String get termLabel => termLabels[term] ?? term;

  static List<ResultGroup> group(Iterable<ResultRow> rows, {required List<AcademicSession> sessions}) {
    final map = <String, ResultGroup>{};
    for (final r in rows) {
      map.putIfAbsent('${r.sessionId}|${r.term}', () => ResultGroup(sessionId: r.sessionId, term: r.term, rows: [])).rows.add(r);
    }
    // Current session first, then newest start date / label.
    final ordered = [...sessions]..sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        final ad = a.startDate, bd = b.startDate;
        if (ad != null && bd != null && ad != bd) return bd.compareTo(ad);
        return b.label.compareTo(a.label);
      });
    int sessionRank(String id) {
      final i = ordered.indexWhere((s) => s.id == id);
      return i < 0 ? 999 : i;
    }

    final out = map.values.toList();
    // Newest session first, then Annual, SEM4 ... SEM1.
    out.sort((a, b) {
      final s = sessionRank(a.sessionId).compareTo(sessionRank(b.sessionId));
      if (s != 0) return s;
      return termOrder.indexOf(b.term).compareTo(termOrder.indexOf(a.term));
    });
    return out;
  }
}

/// One calendar month of someone's attendance.
class MonthStat {
  const MonthStat({required this.year, required this.month, required this.present, required this.absent});
  final int year;
  final int month;
  final int present;
  final int absent;

  int get marked => present + absent;
  double? get percent => marked == 0 ? null : present / marked * 100;
}

/// Useful numbers worked out from the real attendance rows (nothing is invented):
/// streaks, a month-by-month chart and "how many more days can I miss?".
class AttendanceInsights {
  AttendanceInsights(Iterable<AttendanceRecord> records, {this.workingDays, this.minPercent = 75})
      : _sorted = ([...records]..sort((a, b) => a.date.compareTo(b.date)));

  final int? workingDays;
  final int minPercent;
  final List<AttendanceRecord> _sorted;

  int get present => _sorted.where((r) => r.status == AttendanceStatus.present).length;
  int get absent => _sorted.length - present;
  int get marked => _sorted.length;

  /// Days of the session that have not been marked yet (needs the session's working days).
  int? get remaining {
    final w = workingDays;
    if (w == null || w <= 0) return null;
    final left = w - marked;
    return left < 0 ? 0 : left;
  }

  /// Present days needed by the end of the session to reach the minimum percentage.
  int? get requiredPresent {
    final w = workingDays;
    if (w == null || w <= 0) return null;
    return (minPercent * w + 99) ~/ 100;
  }

  /// How many more days can be missed and still finish at or above the minimum.
  /// Negative = even perfect attendance from now on is not enough. null = the session's working days are unknown.
  int? get spareAbsences {
    final need = requiredPresent;
    final left = remaining;
    if (need == null || left == null) return null;
    return present + left - need;
  }

  /// The best percentage still possible by the end of the session (attending every remaining day).
  double? get bestPossiblePercent {
    final w = workingDays;
    final left = remaining;
    if (w == null || w <= 0 || left == null) return null;
    return ((present + left) / w * 100).clamp(0, 100).toDouble();
  }

  /// Without session totals: how many present days in a row bring "present / marked" up to the minimum. 0 = already there.
  /// -1 = impossible (the minimum is 100% and an absence is on record).
  int get presentDaysNeeded {
    if (marked == 0) return 0;
    if (present * 100 >= minPercent * marked) return 0;
    if (minPercent >= 100) return -1;
    final num = minPercent * marked - 100 * present;
    final den = 100 - minPercent;
    return (num + den - 1) ~/ den;
  }

  int get currentStreak {
    var n = 0;
    for (var i = _sorted.length - 1; i >= 0; i--) {
      if (_sorted[i].status != AttendanceStatus.present) break;
      n++;
    }
    return n;
  }

  int get bestStreak {
    var best = 0, run = 0;
    for (final r in _sorted) {
      if (r.status == AttendanceStatus.present) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  /// The last [months] calendar months up to and including [now]'s month, oldest first (months without data are kept).
  List<MonthStat> monthly(DateTime now, {int months = 6}) {
    final out = <MonthStat>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      var p = 0, a = 0;
      for (final r in _sorted) {
        if (r.date.year == m.year && r.date.month == m.month) {
          if (r.status == AttendanceStatus.present) {
            p++;
          } else {
            a++;
          }
        }
      }
      out.add(MonthStat(year: m.year, month: m.month, present: p, absent: a));
    }
    return out;
  }
}
