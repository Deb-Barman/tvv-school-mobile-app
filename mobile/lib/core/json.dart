/// Tolerant JSON readers. The Django API is the source of truth, but the app must
/// never crash because a field is null, missing or a number arrives as a string
/// (DRF sends decimals such as marks as "91.00").
typedef Json = Map<String, dynamic>;

Json asJson(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry('$k', val));
  return <String, dynamic>{};
}

List<Json> asJsonList(Object? v) {
  if (v is List) return v.whereType<Object>().map(asJson).toList();
  return <Json>[];
}

String str(Json j, String key, [String fallback = '']) {
  final v = j[key];
  if (v == null) return fallback;
  return v is String ? v : '$v';
}

String? strOrNull(Json j, String key) {
  final v = j[key];
  if (v == null) return null;
  final s = v is String ? v : '$v';
  return s.isEmpty ? null : s;
}

int intOr(Json j, String key, [int fallback = 0]) => intOrNull(j, key) ?? fallback;

int? intOrNull(Json j, String key) {
  final v = j[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

double dbl(Json j, String key, [double fallback = 0]) => dblOrNull(j, key) ?? fallback;

double? dblOrNull(Json j, String key) {
  final v = j[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool boolOr(Json j, String key, [bool fallback = false]) {
  final v = j[key];
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

List<String> strList(Json j, String key) {
  final v = j[key];
  if (v is List) return v.map((e) => '$e').toList();
  return <String>[];
}

/// "2026-11-05T10:24:33+05:30" -> local DateTime. Returns null if unreadable.
DateTime? dateTimeOrNull(Json j, String key) {
  final s = strOrNull(j, key);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// "2026-11-05" -> DateTime(2026, 11, 5) with no time zone shifting.
DateTime? dateOnlyOrNull(Json j, String key) {
  final s = strOrNull(j, key);
  if (s == null || s.length < 10) return null;
  final y = int.tryParse(s.substring(0, 4));
  final m = int.tryParse(s.substring(5, 7));
  final d = int.tryParse(s.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// DateTime -> "2026-11-05" (what the API expects for a date field).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
