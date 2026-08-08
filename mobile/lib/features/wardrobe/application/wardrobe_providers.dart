import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/network/network_providers.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_controller.dart';
import 'package:mobile/features/wardrobe/data/wardrobe_api.dart';
import 'package:mobile/features/wardrobe/data/wardrobe_repository.dart';

final wardrobeApiProvider = Provider<WardrobeApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);

  return WardrobeApi(apiClient);
});

final wardrobeRepositoryProvider = Provider<WardrobeRepository>((ref) {
  final api = ref.watch(wardrobeApiProvider);

  return WardrobeRepository(api);
});

final wardrobeControllerProvider =
    NotifierProvider<WardrobeController, WardrobeState>(WardrobeController.new);
