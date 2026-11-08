/// School time.
///
/// The school is in India (IST = UTC+5:30, no daylight saving). "Today", the homework window, which day's
/// timetable to show and the attendance date must follow the SCHOOL's calendar, not whatever date or time zone
/// a phone happens to be set to. [schoolNow] returns the current Indian wall-clock time as an ordinary
/// [DateTime] (its fields are the IST date and time), so it can be compared with dates built by `DateTime(y, m, d)`.
DateTime schoolNow() {
  final override = debugSchoolClock;
  if (override != null) return override();
  final t = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

/// Tests set this to freeze the clock. Always null in the real app.
DateTime Function()? debugSchoolClock;
