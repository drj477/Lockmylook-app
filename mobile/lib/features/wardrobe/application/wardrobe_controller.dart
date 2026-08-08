import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/wardrobe/application/wardrobe_providers.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';
import 'package:mobile/features/wardrobe/data/wardrobe_repository.dart';

enum WardrobeStatus { initial, loading, loaded, error }

class WardrobeState {
  const WardrobeState({
    this.status = WardrobeStatus.initial,
    this.items = const [],
    this.categories = const [],
    this.profileId,
    this.errorMessage,
  });

  final WardrobeStatus status;

  final List<WardrobeItem> items;
  final List<WardrobeCategory> categories;

  final String? profileId;
  final String? errorMessage;

  WardrobeState copyWith({
    WardrobeStatus? status,
    List<WardrobeItem>? items,
    List<WardrobeCategory>? categories,
    String? profileId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WardrobeState(
      status: status ?? this.status,
      items: items ?? this.items,
      categories: categories ?? this.categories,
      profileId: profileId ?? this.profileId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class WardrobeController extends Notifier<WardrobeState> {
  late final WardrobeRepository _repository;

  @override
  WardrobeState build() {
    _repository = ref.read(wardrobeRepositoryProvider);

    return const WardrobeState();
  }

  Future<void> loadItems(String profileId) async {
    state = state.copyWith(
      status: WardrobeStatus.loading,
      profileId: profileId,
      clearError: true,
    );

    try {
      final items = await _repository.listItems(profileId);

      state = WardrobeState(
        status: WardrobeStatus.loaded,
        items: items,
        categories: state.categories,
        profileId: profileId,
      );
    } catch (error) {
      state = state.copyWith(
        status: WardrobeStatus.error,
        errorMessage: _messageFromError(error),
      );
    }
  }

  Future<void> loadCategories() async {
    try {
      final categories = await _repository.listCategories();

      state = state.copyWith(categories: categories, clearError: true);
    } catch (error) {
      state = state.copyWith(
        status: WardrobeStatus.error,
        errorMessage: _messageFromError(error),
      );
    }
  }

  Future<bool> createItem({
    required String profileId,
    required WardrobeCreateRequest request,
  }) async {
    state = state.copyWith(
      status: WardrobeStatus.loading,
      profileId: profileId,
      clearError: true,
    );

    try {
      final item = await _repository.createItem(
        profileId: profileId,
        request: request,
      );

      state = WardrobeState(
        status: WardrobeStatus.loaded,
        items: [...state.items, item],
        categories: state.categories,
        profileId: profileId,
      );

      return true;
    } catch (error) {
      state = state.copyWith(
        status: WardrobeStatus.error,
        errorMessage: _messageFromError(error),
      );

      return false;
    }
  }

  Future<bool> updateItem({
    required String profileId,
    required String itemId,
    required WardrobeUpdateRequest request,
  }) async {
    state = state.copyWith(
      status: WardrobeStatus.loading,
      profileId: profileId,
      clearError: true,
    );

    try {
      final updatedItem = await _repository.updateItem(
        profileId: profileId,
        itemId: itemId,
        request: request,
      );

      final items = state.items
          .map((item) => item.id == itemId ? updatedItem : item)
          .toList();

      state = WardrobeState(
        status: WardrobeStatus.loaded,
        items: items,
        categories: state.categories,
        profileId: profileId,
      );

      return true;
    } catch (error) {
      state = state.copyWith(
        status: WardrobeStatus.error,
        errorMessage: _messageFromError(error),
      );

      return false;
    }
  }

  Future<bool> toggleFavorite({
    required String profileId,
    required WardrobeItem item,
  }) {
    return updateItem(
      profileId: profileId,
      itemId: item.id,
      request: WardrobeUpdateRequest(favorite: !item.favorite),
    );
  }

  Future<bool> deleteItem({
    required String profileId,
    required String itemId,
  }) async {
    state = state.copyWith(
      status: WardrobeStatus.loading,
      profileId: profileId,
      clearError: true,
    );

    try {
      await _repository.deleteItem(profileId: profileId, itemId: itemId);

      final items = state.items.where((item) => item.id != itemId).toList();

      state = WardrobeState(
        status: WardrobeStatus.loaded,
        items: items,
        categories: state.categories,
        profileId: profileId,
      );

      return true;
    } catch (error) {
      state = state.copyWith(
        status: WardrobeStatus.error,
        errorMessage: _messageFromError(error),
      );

      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _messageFromError(Object error) {
    return error.toString();
  }
}
