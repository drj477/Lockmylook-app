import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final dioClientProvider = Provider<DioClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);

  return DioClient(secureStorage: secureStorage);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dioClient = ref.watch(dioClientProvider);

  return ApiClient(dioClient);
});

final authApiProvider = Provider<AuthApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);

  return AuthApi(apiClient);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authApi = ref.watch(authApiProvider);

  final secureStorage = ref.watch(secureStorageProvider);

  return AuthRepository(authApi: authApi, secureStorage: secureStorage);
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
