import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/features/outfits/data/models/outfit_models.dart';

class OutfitApi {
  OutfitApi(this._apiClient);

  final ApiClient _apiClient;

  Future<OutfitGenerateResponse> generateOutfits({
    required String profileId,
    required OutfitGenerateRequest request,
  }) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.profiles}/$profileId/outfits/generate',
      data: request.toJson(),
    );

    return OutfitGenerateResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
