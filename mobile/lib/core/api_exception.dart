import 'json.dart';

enum ApiErrorKind { network, timeout, unauthorized, forbidden, notFound, validation, throttled, server, unknown }

/// One error type for every failed call, with a message that is safe to show to a student.
class ApiException implements Exception {
  ApiException(this.kind, this.message, {this.status, this.fieldErrors = const {}});

  final ApiErrorKind kind;
  final String message;
  final int? status;

  /// Field name -> first message, for forms (e.g. {"username": "A user with that username already exists."}).
  final Map<String, String> fieldErrors;

  bool get isNetwork => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;
  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;

  @override
  String toString() => message;

  static ApiException network([String? detail]) => ApiException(
        ApiErrorKind.network,
        detail ?? 'Can\u2019t reach the school server. Check your internet connection and try again.',
      );

  static ApiException timeout() => ApiException(
        ApiErrorKind.timeout,
        'The school server is taking too long to answer. It may be waking up \u2014 please try again in a moment.',
      );

  /// Builds the right exception from an HTTP status and the decoded JSON body (if any).
  static ApiException fromResponse(int status, Object? body) {
    final fields = <String, String>{};
    String? message;
    if (body is Map) {
      final map = asJson(body);
      final detail = map['detail'];
      if (detail is String && detail.isNotEmpty) message = detail;
      for (final entry in map.entries) {
        if (entry.key == 'detail' || entry.key == 'code') continue;
        final first = _firstMessage(entry.value);
        if (first != null) fields[entry.key] = first;
      }
      if (message == null && fields.isNotEmpty) {
        final e = fields.entries.first;
        message = (e.key == 'non_field_errors') ? e.value : '${_label(e.key)}: ${e.value}';
      }
    } else if (body is List && body.isNotEmpty) {
      message = _firstMessage(body);
    }

    switch (status) {
      case 400:
      case 422:
        return ApiException(ApiErrorKind.validation, message ?? 'Please check the details and try again.',
            status: status, fieldErrors: fields);
      case 401:
        return ApiException(ApiErrorKind.unauthorized, message ?? 'Your session has ended. Please sign in again.', status: status);
      case 403:
        return ApiException(ApiErrorKind.forbidden, message ?? 'You don\u2019t have permission to do that.', status: status);
      case 404:
        return ApiException(ApiErrorKind.notFound, message ?? 'That item could not be found.', status: status);
      case 429:
        return ApiException(ApiErrorKind.throttled, message ?? 'Too many attempts. Please wait a minute and try again.', status: status);
      default:
        if (status >= 500) {
          return ApiException(ApiErrorKind.server, 'The school server had a problem (error $status). Please try again shortly.',
              status: status);
        }
        return ApiException(ApiErrorKind.unknown, message ?? 'Something went wrong (error $status).', status: status);
    }
  }

  static String? _firstMessage(Object? v) {
    if (v is String) return v.isEmpty ? null : v;
    if (v is List && v.isNotEmpty) {
      final f = v.first;
      if (f is String) return f;
      if (f is Map) return _firstMessage(f.values.isNotEmpty ? f.values.first : null);
    }
    if (v is Map && v.isNotEmpty) return _firstMessage(v.values.first);
    return null;
  }

  static String _label(String key) {
    final s = key.replaceAll('_', ' ').trim();
    return s.isEmpty ? key : s[0].toUpperCase() + s.substring(1);
  }
}
