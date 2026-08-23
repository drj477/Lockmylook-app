import 'package:mobile/features/outfits/data/models/virtual_try_on_models.dart';
import 'package:mobile/features/outfits/data/virtual_try_on_api.dart';

class VirtualTryOnRepository {
  VirtualTryOnRepository(this._api);

  final VirtualTryOnApi _api;

  Future<VirtualTryOnResult> generate({required String profileId, required VirtualTryOnRequest request}) {
    return _api.generate(profileId: profileId, request: request);
  }

  Future<VirtualTryOnSaveResult> setSaved({required String profileId, required String resultId, required bool saved}) {
    return _api.setSaved(profileId: profileId, resultId: resultId, saved: saved);
  }

  Future<List<VirtualTryOnResult>> history({required String profileId}) {
    return _api.history(profileId: profileId);
  }

  Future<void> delete({required String profileId, required String resultId}) {
    return _api.delete(profileId: profileId, resultId: resultId);
  }

  Future<void> deleteAll({required String profileId}) {
    return _api.deleteAll(profileId: profileId);
  }
}
