import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

/// JWT pair in the Android Keystore (EncryptedSharedPreferences) / iOS Keychain.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _s;
  static const _kAccess = 'tvv_access_token';
  static const _kRefresh = 'tvv_refresh_token';

  @override
  Future<String?> readAccess() => _guard(() => _s.read(key: _kAccess));

  @override
  Future<String?> readRefresh() => _guard(() => _s.read(key: _kRefresh));

  @override
  Future<void> save({required String access, String? refresh}) async {
    await _s.write(key: _kAccess, value: access);
    if (refresh != null) await _s.write(key: _kRefresh, value: refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
  }

  // A corrupted keystore (rare, e.g. after a restore onto a new phone) must mean "signed out", never a crash.
  Future<String?> _guard(Future<String?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      try {
        await clear();
      } catch (_) {}
      return null;
    }
  }
}
