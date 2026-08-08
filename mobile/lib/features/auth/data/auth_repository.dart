import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';

class AuthRepository {
  AuthRepository({required this._authApi, required this._secureStorage});

  final AuthApi _authApi;
  final SecureStorage _secureStorage;

  Future<Account> signup({required String email, required String password}) {
    return _authApi.signup(email: email, password: password);
  }

  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _authApi.login(email: email, password: password);

    await _secureStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return tokens;
  }

  Future<TokenPair> refresh() async {
    final refreshToken = await _secureStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('No refresh token available.');
    }

    final tokens = await _authApi.refresh(refreshToken);

    await _secureStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return tokens;
  }

  Future<void> logout() async {
    try {
      await _authApi.logout();
    } finally {
      await _secureStorage.clearTokens();
    }
  }

  Future<String?> getAccessToken() {
    return _secureStorage.getAccessToken();
  }

  Future<bool> hasSession() async {
    final token = await _secureStorage.getRefreshToken();

    return token != null && token.isNotEmpty;
  }

  Future<void> clearLocalSession() {
    return _secureStorage.clearTokens();
  }
}
