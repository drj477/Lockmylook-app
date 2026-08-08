import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/storage/secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final dioClientProvider = Provider<DioClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);

  return DioClient(secureStorage: secureStorage);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dioClient = ref.watch(dioClientProvider);

  return ApiClient(dioClient);
});
