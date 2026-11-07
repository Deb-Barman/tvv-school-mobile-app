import '../core/api_client.dart';
import '../core/config.dart';
import '../core/secure_token_store.dart';
import '../core/token_store.dart';
import '../data/repositories/academics_repository.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/profile_repository.dart';

/// Everything that talks to the backend, created once and shared through [AppScope].
class AppServices {
  AppServices._(this.api, this.warmUpOnStart)
      : auth = AuthRepository(api),
        academics = AcademicsRepository(api),
        content = ContentRepository(api),
        profile = ProfileRepository(api),
        admin = AdminRepository(api);

  factory AppServices.create({String? baseUrl, TokenStore? tokens, bool warmUpOnStart = true}) =>
      AppServices._(ApiClient(baseUrl: baseUrl ?? AppConfig.apiBaseUrl, tokens: tokens ?? SecureTokenStore()), warmUpOnStart);

  /// Wake the (free-tier) server while the sign-in screen is showing. Tests switch this off.
  final bool warmUpOnStart;

  final ApiClient api;
  final AuthRepository auth;
  final AcademicsRepository academics;
  final ContentRepository content;
  final ProfileRepository profile;
  final AdminRepository admin;
}
