import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/network/network_providers.dart';
import 'package:mobile/features/outfits/data/models/outfit_models.dart';
import 'package:mobile/features/outfits/data/outfit_api.dart';
import 'package:mobile/features/outfits/data/outfit_repository.dart';

final outfitApiProvider = Provider<OutfitApi>((ref) {
  return OutfitApi(ref.watch(apiClientProvider));
});

final outfitRepositoryProvider = Provider<OutfitRepository>((ref) {
  return OutfitRepository(ref.watch(outfitApiProvider));
});

final outfitGenerationProvider =
    FutureProvider.family<OutfitGenerateResponse, ({
      String profileId,
      OutfitGenerateRequest request,
    })>((ref, args) {
  return ref.watch(outfitRepositoryProvider).generateOutfits(
        profileId: args.profileId,
        request: args.request,
      );
});
