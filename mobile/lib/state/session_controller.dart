import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';
import 'app_services.dart';

enum SessionStatus { booting, signedOut, signedIn, bootFailed }

/// Who is signed in. The UI only decides what to SHOW from [user.role]; the Django API enforces what is ALLOWED.
class SessionController extends ChangeNotifier {
  SessionController(this._services) {
    _services.api.onSessionExpired = _handleExpired;
  }

  final AppServices _services;

  SessionStatus status = SessionStatus.booting;
  AppUser? user;

  /// A short message for the sign-in screen (for example "Your session ended").
  String? notice;
  String? bootError;

  /// Runs at app start: is the stored session still valid?
  Future<void> boot() async {
    status = SessionStatus.booting;
    bootError = null;
    notifyListeners();
    try {
      if (!await _services.api.hasSession()) {
        status = SessionStatus.signedOut;
      } else {
        user = await _services.auth.me();
        status = SessionStatus.signedIn;
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        user = null;
        status = SessionStatus.signedOut;
      } else {
        // Offline or the server is waking up: keep the session and let the person retry; never sign out for this.
        status = SessionStatus.bootFailed;
        bootError = e.message;
      }
    } catch (_) {
      status = SessionStatus.bootFailed;
      bootError = 'Something went wrong while opening the app. Please try again.';
    }
    notifyListeners();
  }

  Future<void> login({required String username, required String password, required LoginPortal portal}) async {
    final u = await _services.auth.login(username: username, password: password, portal: portal);
    user = u;
    notice = null;
    status = SessionStatus.signedIn;
    notifyListeners();
  }

  Future<void> logout({String? notice}) async {
    user = null;
    this.notice = notice;
    status = SessionStatus.signedOut;
    notifyListeners();
    await _services.auth.signOut();
  }

  void _handleExpired() {
    if (status != SessionStatus.signedIn) return;
    user = null;
    notice = 'Your session ended. Please sign in again.';
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  void clearNotice() {
    notice = null;
  }
}
