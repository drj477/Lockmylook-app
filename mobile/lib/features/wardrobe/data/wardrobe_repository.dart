import 'dart:io';

import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';
import 'package:mobile/features/wardrobe/data/wardrobe_api.dart';

class WardrobeRepository {
  WardrobeRepository(this._api);

  final WardrobeApi _api;

  Future<List<WardrobeItem>> listItems(String profileId) {
    return _api.listItems(profileId);
  }

  Future<WardrobeItem> getItem({
    required String profileId,
    required String itemId,
  }) {
    return _api.getItem(profileId: profileId, itemId: itemId);
  }

  Future<WardrobeItem> createItem({
    required String profileId,
    required WardrobeCreateRequest request,
  }) {
    return _api.createItem(profileId: profileId, request: request);
  }

  Future<WardrobeItem> updateItem({
    required String profileId,
    required String itemId,
    required WardrobeUpdateRequest request,
  }) {
    return _api.updateItem(
      profileId: profileId,
      itemId: itemId,
      request: request,
    );
  }

  Future<Map<String, dynamic>> uploadImage({
    required String profileId,
    required String itemId,
    required File file,
  }) {
    return _api.uploadImage(
      profileId: profileId,
      itemId: itemId,
      file: file,
    );
  }

  Future<void> deleteItem({required String profileId, required String itemId}) {
    return _api.deleteItem(profileId: profileId, itemId: itemId);
  }

  Future<List<WardrobeCategory>> listCategories() {
    return _api.listCategories();
  }
}
