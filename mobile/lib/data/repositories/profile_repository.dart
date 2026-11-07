import '../../core/api_client.dart';
import '../../core/json.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<MyProfile> mine() async => MyProfile.fromJson(await _api.getMap('/auth/me/profile/'));

  /// PATCH sends only the fields in [changes], so parts the app does not edit (project cards, achievement cards)
  /// are never overwritten.
  Future<MyProfile> update(Json changes) async => MyProfile.fromJson(await _api.patch('/auth/me/profile/', changes));

  /// A public page. The server answers 404 for missing, private and disabled profiles alike.
  Future<PublicProfile> publicProfile({required String role, required String username}) async =>
      PublicProfile.fromJson(await _api.getMap('/auth/profiles/$role/${Uri.encodeComponent(username)}/'));
}
