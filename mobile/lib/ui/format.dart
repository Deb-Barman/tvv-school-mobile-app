const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
];

String fmtDate(DateTime? d) => d == null ? '\u2014' : '${d.day} ${_months[d.month - 1]} ${d.year}';
String fmtDateShort(DateTime? d) => d == null ? '\u2014' : '${d.day} ${_months[d.month - 1]}';
String monthName(int month) => _monthsLong[month - 1];
String monthShort(int month) => _months[month - 1];

/// "10:00:00" / "10:00" -> "10:00 AM"
String fmtTime(String? t) {
  if (t == null || t.length < 4) return '';
  final parts = t.split(':');
  final h = int.tryParse(parts[0]);
  final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  if (h == null || m == null) return t;
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $suffix';
}

/// "HH:MM" for the API from a time of day.
String apiTime(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String fmtDateTime(DateTime? d) {
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${fmtDate(d)}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today", "Tomorrow", "In 3 days", "2 days ago"
String relativeDay(DateTime? d) {
  if (d == null) return '';
  final diff = dayOnly(d).difference(dayOnly(DateTime.now())).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1) return 'In $diff days';
  return '${-diff} days ago';
}

String pct(double? v, [int decimals = 0]) => v == null ? '\u2014' : '${v.toStringAsFixed(decimals)}%';

String marks(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
