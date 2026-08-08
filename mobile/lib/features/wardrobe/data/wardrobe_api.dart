import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';

class WardrobeApi {
  WardrobeApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<WardrobeItem>> listItems(String profileId) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.profiles}/$profileId/wardrobe',
    );

    final items = response.data as List<dynamic>;

    return items
        .map((item) => WardrobeItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WardrobeItem> getItem({
    required String profileId,
    required String itemId,
  }) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.profiles}/$profileId/wardrobe/$itemId',
    );

    return WardrobeItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WardrobeItem> createItem({
    required String profileId,
    required WardrobeCreateRequest request,
  }) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.profiles}/$profileId/wardrobe',
      data: request.toJson(),
    );

    return WardrobeItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WardrobeItem> updateItem({
    required String profileId,
    required String itemId,
    required WardrobeUpdateRequest request,
  }) async {
    final response = await _apiClient.patch(
      '${ApiEndpoints.profiles}/$profileId/wardrobe/$itemId',
      data: request.toJson(),
    );

    return WardrobeItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteItem({
    required String profileId,
    required String itemId,
  }) async {
    await _apiClient.delete(
      '${ApiEndpoints.profiles}/$profileId/wardrobe/$itemId',
    );
  }

  Future<List<WardrobeCategory>> listCategories() async {
    final response = await _apiClient.get(ApiEndpoints.wardrobeCategories);

    final data = response.data as Map<String, dynamic>;
    final categories = data['data'] as List<dynamic>;

    return categories
        .map((item) => WardrobeCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
