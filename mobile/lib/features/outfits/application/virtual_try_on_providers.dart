import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/network/network_providers.dart';
import 'package:mobile/features/outfits/data/virtual_try_on_api.dart';
import 'package:mobile/features/outfits/data/virtual_try_on_repository.dart';

final virtualTryOnApiProvider = Provider<VirtualTryOnApi>((ref) {
  return VirtualTryOnApi(ref.watch(apiClientProvider));
});

final virtualTryOnRepositoryProvider = Provider<VirtualTryOnRepository>((ref) {
  return VirtualTryOnRepository(ref.watch(virtualTryOnApiProvider));
});
