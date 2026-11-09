import 'attendance_stats.dart' show ResultGroup;
import 'models/academics.dart';

/// One subject over all terms.
class SubjectAverage {
  const SubjectAverage({required this.subjectId, required this.percent, required this.terms});
  final String subjectId;
  final double percent;
  final int terms;
}

/// Numbers worked out from a student's real result rows: overall percentage, best / weakest subject, change since the
/// previous term. Takes the groups newest-first (as [ResultGroup.group] returns them).
class ResultsOverview {
  ResultsOverview(List<ResultGroup> newestFirst) : chronological = newestFirst.reversed.toList();

  /// Oldest term first (good for a trend chart).
  final List<ResultGroup> chronological;

  double get totalMarks => chronological.fold(0.0, (a, g) => a + g.total);
  double get fullMarks => chronological.fold(0.0, (a, g) => a + g.fullTotal);
  double get overallPercent => fullMarks <= 0 ? 0 : totalMarks / fullMarks * 100;

  /// Every subject's overall percentage, best first.
  List<SubjectAverage> get subjects {
    final marks = <String, double>{}, full = <String, double>{}, count = <String, int>{};
    for (final g in chronological) {
      for (final r in g.rows) {
        marks[r.subjectId] = (marks[r.subjectId] ?? 0) + r.marks;
        full[r.subjectId] = (full[r.subjectId] ?? 0) + r.fullMarks;
        count[r.subjectId] = (count[r.subjectId] ?? 0) + 1;
      }
    }
    final out = [
      for (final id in marks.keys) SubjectAverage(subjectId: id, percent: (full[id] ?? 0) <= 0 ? 0 : marks[id]! / full[id]! * 100, terms: count[id] ?? 0)
    ]..sort((a, b) => b.percent.compareTo(a.percent));
    return out;
  }

  /// Only meaningful with at least two subjects.
  SubjectAverage? get best => subjects.length < 2 ? null : subjects.first;
  SubjectAverage? get weakest => subjects.length < 2 ? null : subjects.last;

  /// Overall percentage change of term [index] compared with the term before it (null for the first term).
  double? termDelta(int index) => index <= 0 ? null : chronological[index].percent - chronological[index - 1].percent;

  /// Change of one subject compared with the last earlier term that also had it (null when there is none).
  double? subjectDelta(int index, String subjectId) {
    ResultRow? find(ResultGroup g) {
      for (final r in g.rows) {
        if (r.subjectId == subjectId) return r;
      }
      return null;
    }

    final now = find(chronological[index]);
    if (now == null) return null;
    for (var i = index - 1; i >= 0; i--) {
      final before = find(chronological[i]);
      if (before != null) return now.percent - before.percent;
    }
    return null;
  }
}

/// "above the minimum" style words for a percentage (shared by the results screens).
String performanceTone(double percent) => percent >= 60 ? 'good' : (percent >= 40 ? 'warn' : 'bad');
