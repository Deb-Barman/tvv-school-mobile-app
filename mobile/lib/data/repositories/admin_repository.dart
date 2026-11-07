import '../../core/api_client.dart';
import '../../core/json.dart';
import '../models/admin.dart';
import '../models/user.dart';

class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<AdminStats> stats() async => AdminStats.fromJson(await _api.getMap('/auth/admin/stats/'));

  Future<List<AdminUser>> users() async => (await _api.listAll('/auth/admin/users/')).map(AdminUser.fromJson).toList();

  Future<AdminUser> createUser(
          {required String username,
          required String password,
          required String fullName,
          required Role role,
          String phone = '',
          String email = ''}) async =>
      AdminUser.fromJson(await _api.post('/auth/admin/users/', {
        'username': username.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'role': role.api,
        'phone': phone.trim(),
        'email': email.trim(),
      }));

  Future<AdminUser> updateUser(String id, {String? username, String? fullName, String? phone, String? email, bool? isActive}) async {
    final body = <String, Object?>{
      if (username != null) 'username': username.trim(),
      if (fullName != null) 'full_name': fullName.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (email != null) 'email': email.trim(),
      if (isActive != null) 'is_active_account': isActive,
    };
    // The update serializer returns only the editable fields, so re-read the full row.
    await _api.patch('/auth/admin/users/$id/', body);
    return AdminUser.fromJson(await _api.getMap('/auth/admin/users/$id/'));
  }

  Future<void> deleteUser(String id) => _api.delete('/auth/admin/users/$id/');

  Future<void> resetPassword(String id, String newPassword) async {
    await _api.post('/auth/admin/users/$id/reset-password/', {'new_password': newPassword});
  }

  Future<void> unlock(String id) async {
    await _api.post('/auth/admin/users/$id/unlock/');
  }

  /// People who tapped "I forgot my password". Each row also carries the account id when the username is real.
  Future<List<({ResetRequest request, String? userId})>> resetRequests() async {
    final raw = await _api.getRaw('/auth/admin/reset-requests/');
    return asJsonList(raw).map((j) => (request: ResetRequest.fromJson(j), userId: ResetRequest.userId(j))).toList();
  }

  Future<void> dismissResetRequest(String id) async {
    await _api.post('/auth/admin/reset-requests/$id/dismiss/');
  }

  Future<AttendanceReport> attendanceReport({String kind = 'students', String? sessionId, String? classId}) async =>
      AttendanceReport.fromJson(
          await _api.getMap('/academics/attendance-report/', query: {'kind': kind, 'session': sessionId, 'school_class': classId}));
}
