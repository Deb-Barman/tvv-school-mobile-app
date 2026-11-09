/// Build-time configuration. Nothing secret lives in the app: the only thing it
/// needs is the address of the school's existing Django REST API.
///
/// Override at build time with:
///   flutter build apk --dart-define=API_BASE_URL=https://your-backend.onrender.com/api
class AppConfig {
  AppConfig._();

  /// Base URL of the Django REST API, WITHOUT a trailing slash and INCLUDING `/api`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tufanganj-vivekanand-vidyalaya.onrender.com/api',
  );

  /// Public website (used for "Open on website" links and the About screen).
  static const String websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'https://tufanganj-vivekanand-vidyalaya.vercel.app',
  );

  static const String schoolName = 'Tufanganj Vivekananda Vidyalaya';
  static const String schoolNameFull = 'Tufanganj Vivekananda Vidyalaya (H.S.)';
  static const String schoolTown = 'Tufanganj, Cooch Behar, West Bengal, India';
  static const String motto = 'Knowledge \u00b7 Character \u00b7 Progress';
  static const int establishedYear = 1964;

  static const String appVersion = '1.3.0';

  /// Filled in by the cloud build (see .github/workflows/mobile-build.yml); empty / 0 when running locally.
  static const String updateRepo = String.fromEnvironment('UPDATE_REPO');
  static const int appBuild = int.fromEnvironment('APP_BUILD', defaultValue: 0);

  /// Public page of the latest build (shared from Settings -> "Share this app").
  static const String downloadUrl = String.fromEnvironment('APP_DOWNLOAD_URL');
}
