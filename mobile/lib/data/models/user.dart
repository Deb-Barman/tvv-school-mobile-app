import '../../core/json.dart';

enum Role {
  superAdmin('SUPER_ADMIN', 'Super Admin'),
  teacher('TEACHER', 'Teacher'),
  student('STUDENT', 'Student');

  const Role(this.api, this.label);
  final String api;
  final String label;

  static Role? parse(String? v) {
    for (final r in Role.values) {
      if (r.api == v) return r;
    }
    return null;
  }
}

/// The signed-in person (`user` in the login response and GET /auth/me/).
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.phone = '',
    this.email = '',
    this.isActive = true,
    this.mustChangePassword = false,
  });

  final String id;
  final String username;
  final String fullName;
  final Role role;
  final String phone;
  final String email;
  final bool isActive;
  final bool mustChangePassword;

  bool get isSuperAdmin => role == Role.superAdmin;
  bool get isTeacher => role == Role.teacher;
  bool get isStudent => role == Role.student;
  bool get isStaff => isSuperAdmin || isTeacher;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? username : parts.first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return username.isEmpty ? '?' : username[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Returns null if the server sent an unknown role, so the app never guesses permissions.
  static AppUser? fromJson(Json j) {
    final role = Role.parse(strOrNull(j, 'role'));
    if (role == null) return null;
    return AppUser(
      id: str(j, 'id'),
      username: str(j, 'username'),
      fullName: str(j, 'full_name'),
      role: role,
      phone: str(j, 'phone'),
      email: str(j, 'email'),
      isActive: boolOr(j, 'is_active_account', true),
      mustChangePassword: boolOr(j, 'must_change_password'),
    );
  }
}

/// A Teacher/Student account as the Super Admin sees it (GET /auth/admin/users/).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.phone = '',
    this.email = '',
    this.isActive = true,
    this.lockedUntil,
    this.failedAttempts = 0,
    this.lastLogin,
  });

  final String id;
  final String username;
  final String fullName;
  final Role role;
  final String phone;
  final String email;
  final bool isActive;
  final DateTime? lockedUntil;
  final int failedAttempts;
  final DateTime? lastLogin;

  bool get isLocked => lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  static AdminUser fromJson(Json j) => AdminUser(
        id: str(j, 'id'),
        username: str(j, 'username'),
        fullName: str(j, 'full_name'),
        role: Role.parse(strOrNull(j, 'role')) ?? Role.student,
        phone: str(j, 'phone'),
        email: str(j, 'email'),
        isActive: boolOr(j, 'is_active_account', true),
        lockedUntil: dateTimeOrNull(j, 'locked_until'),
        failedAttempts: intOr(j, 'failed_login_attempts'),
        lastLogin: dateTimeOrNull(j, 'last_login'),
      );
}

class ResetRequest {
  const ResetRequest(
      {required this.id,
      required this.username,
      required this.fullName,
      required this.roleLabel,
      required this.note,
      required this.known,
      this.createdAt});

  final String id;
  final String username;
  final String fullName;
  final String roleLabel;
  final String note;
  final bool known;
  final DateTime? createdAt;

  /// The matching [AdminUser.id] (needed to set a new password), when the account exists.
  static String? userId(Json j) => strOrNull(j, 'user');

  static ResetRequest fromJson(Json j) => ResetRequest(
        id: str(j, 'id'),
        username: str(j, 'username'),
        fullName: str(j, 'full_name'),
        roleLabel: Role.parse(strOrNull(j, 'role'))?.label ?? '',
        note: str(j, 'note'),
        known: boolOr(j, 'known'),
        createdAt: dateTimeOrNull(j, 'created_at'),
      );
}
