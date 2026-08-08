import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/network/network_providers.dart';
import 'package:mobile/features/profiles/application/profile_controller.dart';
import 'package:mobile/features/profiles/data/profile_api.dart';
import 'package:mobile/features/profiles/data/profile_repository.dart';

final profileApiProvider = Provider<ProfileApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);

  return ProfileApi(apiClient);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final profileApi = ref.watch(profileApiProvider);

  return ProfileRepository(profileApi);
});

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
