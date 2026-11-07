import '../../core/api_client.dart';
import '../../core/json.dart';
import '../models/user.dart';

enum LoginPortal { schoolMember, superAdmin }

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// POST /auth/staff-login/ (students + teachers) or /auth/admin-login/ (Super Admin: e-mail + password).
  /// Both are rejected by the server for the wrong kind of account, so the portal choice is not a security boundary in the app.
  Future<AppUser> login({required String username, required String password, LoginPortal portal = LoginPortal.schoolMember}) async {
    final path = portal == LoginPortal.superAdmin ? '/auth/admin-login/' : '/auth/staff-login/';
    final data = await _api.post(path, {'username': username.trim(), 'password': password}, false, true);
    final access = str(data, 'access');
    final refresh = str(data, 'refresh');
    final user = AppUser.fromJson(asJson(data['user']));
    if (access.isEmpty || refresh.isEmpty || user == null) {
      throw StateError('Unexpected sign-in response from the server.');
    }
    await _api.setSession(access: access, refresh: refresh);
    return user;
  }

  /// GET /auth/me/ - also the check that a stored session is still valid at app start.
  Future<AppUser> me() async {
    final user = AppUser.fromJson(await _api.getMap('/auth/me/'));
    if (user == null) throw StateError('Unexpected account response from the server.');
    return user;
  }

  Future<void> changePassword({required String current, required String next}) async {
    await _api.post('/auth/me/change-password/', {'current_password': current, 'new_password': next});
  }

  /// Nobody can read a password; this puts the person in the Super Admin's queue (always answers 202).
  Future<String> forgotPassword({required String username, String note = ''}) async {
    final data = await _api.post('/auth/forgot-password/', {'username': username.trim(), 'note': note}, false);
    return str(data, 'detail', 'The school office has been told.');
  }

  Future<void> signOut() => _api.signOut();
}
