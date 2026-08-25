import 'dart:io';

import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';
import 'package:mobile/features/wardrobe/data/wardrobe_api.dart';

class WardrobeRepository {
  WardrobeRepository(this._api);

  final WardrobeApi _api;

  Future<List<WardrobeItem>> listItems(String profileId) => _api.listItems(profileId);

  Future<WardrobeItem> getItem({required String profileId, required String itemId}) =>
      _api.getItem(profileId: profileId, itemId: itemId);

  Future<WardrobeItem> createItem({required String profileId, required WardrobeCreateRequest request}) =>
      _api.createItem(profileId: profileId, request: request);

  Future<WardrobeItem> updateItem({
    required String profileId,
    required String itemId,
    required WardrobeUpdateRequest request,
  }) => _api.updateItem(profileId: profileId, itemId: itemId, request: request);

  Future<Map<String, dynamic>> uploadImage({
    required String profileId,
    required String itemId,
    required File file,
    required bool removeBackground,
  }) => _api.uploadImage(
        profileId: profileId,
        itemId: itemId,
        file: file,
        removeBackground: removeBackground,
      );

  Future<void> deleteItem({required String profileId, required String itemId}) =>
      _api.deleteItem(profileId: profileId, itemId: itemId);

  Future<List<WardrobeCategory>> listCategories() => _api.listCategories();
}
