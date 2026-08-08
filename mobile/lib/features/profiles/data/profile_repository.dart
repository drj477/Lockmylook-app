import 'package:mobile/features/profiles/data/models/profile_models.dart';
import 'package:mobile/features/profiles/data/profile_api.dart';

class ProfileRepository {
  ProfileRepository(this._profileApi);

  final ProfileApi _profileApi;

  Future<List<Profile>> listProfiles() {
    return _profileApi.listProfiles();
  }

  Future<Profile> createProfile({required String name, String? avatarUrl}) {
    return _profileApi.createProfile(
      ProfileCreateRequest(name: name, avatarUrl: avatarUrl),
    );
  }

  Future<Profile> getProfile(String profileId) {
    return _profileApi.getProfile(profileId);
  }

  Future<void> deleteProfile(String profileId) {
    return _profileApi.deleteProfile(profileId);
  }
}
