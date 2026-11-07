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
