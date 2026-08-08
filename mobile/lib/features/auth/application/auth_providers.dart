import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/network/network_providers.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';

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
