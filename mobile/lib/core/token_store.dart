/// Where the JWT pair lives. The real implementation (secure_token_store.dart) uses the
/// Android Keystore / iOS Keychain; tests use [MemoryTokenStore].
abstract class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();

  /// Saves a new access token. Pass [refresh] whenever the server returned one: refresh
  /// tokens ROTATE on this backend (the old one is blacklisted at once), so the new one
  /// must always replace it or the next refresh fails.
  Future<void> save({required String access, String? refresh});

  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? access;
  String? refresh;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> save({required String access, String? refresh}) async {
    this.access = access;
    if (refresh != null) this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}
