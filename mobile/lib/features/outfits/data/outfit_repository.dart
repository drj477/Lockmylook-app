import 'package:mobile/features/outfits/data/models/outfit_models.dart';
import 'package:mobile/features/outfits/data/outfit_api.dart';

class OutfitRepository {
  OutfitRepository(this._api);

  final OutfitApi _api;

  Future<OutfitGenerateResponse> generateOutfits({
    required String profileId,
    required OutfitGenerateRequest request,
  }) {
    return _api.generateOutfits(profileId: profileId, request: request);
  }
}
