import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/update_checker.dart';
import '../core/config.dart';
import '../core/response_cache.dart';
import '../core/secure_token_store.dart';
import '../core/token_store.dart';
import '../data/repositories/academics_repository.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/profile_repository.dart';
import 'prefs_response_cache.dart';

/// Everything that talks to the backend, created once and shared through [AppScope].
class AppServices {
  AppServices._(this.api, this.warmUpOnStart)
      : auth = AuthRepository(api),
        academics = AcademicsRepository(api),
        content = ContentRepository(api),
        profile = ProfileRepository(api),
        admin = AdminRepository(api) {
    api.onOfflineData = (offline) => offlineData.value = offline;
  }

  factory AppServices.create({String? baseUrl, TokenStore? tokens, bool warmUpOnStart = true, ResponseCache? cache}) => AppServices._(
      ApiClient(baseUrl: baseUrl ?? AppConfig.apiBaseUrl, tokens: tokens ?? SecureTokenStore(), cache: cache ?? PrefsResponseCache()),
      warmUpOnStart);

  /// true while the screens are showing saved copies because the server could not be reached.
  final ValueNotifier<bool> offlineData = ValueNotifier<bool>(false);

  /// The signed-in person's profile picture (a link), or null. Shown in the bottom bar, the menu and the dashboards.
  final ValueNotifier<String?> myPhoto = ValueNotifier<String?>(null);

  /// A newer build of the app, when one is waiting (null = up to date / unknown).
  final ValueNotifier<UpdateInfo?> update = ValueNotifier<UpdateInfo?>(null);

  /// Asks GitHub for the latest build. Returns true when the check could run (the app was downloaded from a release).
  Future<bool> checkForUpdate() async {
    if (AppConfig.updateRepo.isEmpty || AppConfig.appBuild <= 0) return false;
    final checker = UpdateChecker(AppConfig.updateRepo);
    try {
      final latest = await checker.latest();
      update.value = (latest != null && latest.build > AppConfig.appBuild) ? latest : null;
    } finally {
      checker.close();
    }
    return true;
  }

  /// Loads the signed-in person's picture. Quietly does nothing when there is none (or no profile, e.g. Super Admin).
  Future<void> refreshMyPhoto() async {
    try {
      final p = await profile.mine();
      myPhoto.value = p.displayPhoto;
    } catch (_) {}
  }

  /// Wake the (free-tier) server while the sign-in screen is showing. Tests switch this off.
  final bool warmUpOnStart;

  final ApiClient api;
  final AuthRepository auth;
  final AcademicsRepository academics;
  final ContentRepository content;
  final ProfileRepository profile;
  final AdminRepository admin;
}
