/// One timetable slot, in minutes since midnight.
class PeriodSlot {
  const PeriodSlot({required this.startMin, required this.endMin, required this.title, this.room = '', this.subtitle = '', this.isBreak = false});
  final int startMin;
  final int endMin;
  final String title;
  final String subtitle;
  final String room;
  final bool isBreak;
}

/// What is happening (or comes next) in a school day.
class NextPeriodInfo {
  const NextPeriodInfo({required this.slot, required this.live, required this.minutes});
  final PeriodSlot slot;

  /// true = the period is running now ([minutes] left); false = it starts in [minutes].
  final bool live;
  final int minutes;
}

/// "HH:MM" or "HH:MM:SS" -> minutes since midnight (0 when it cannot be read).
int minutesOfDay(String t) {
  final p = t.split(':');
  return (int.tryParse(p.first) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

/// The period running now, otherwise the next one today; null when the school day is over (or there are no periods).
NextPeriodInfo? nextPeriod(Iterable<PeriodSlot> today, int nowMin) {
  final slots = today.where((s) => !s.isBreak).toList()..sort((a, b) => a.startMin.compareTo(b.startMin));
  for (final s in slots) {
    if (nowMin >= s.startMin && nowMin < s.endMin) return NextPeriodInfo(slot: s, live: true, minutes: s.endMin - nowMin);
  }
  for (final s in slots) {
    if (s.startMin > nowMin) return NextPeriodInfo(slot: s, live: false, minutes: s.startMin - nowMin);
  }
  return null;
}

/// 25 -> "25 min", 65 -> "1 h 5 min", 120 -> "2 h".
String minutesLabel(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}
