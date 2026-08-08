import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';

class AuthApi {
  AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Account> signup({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.signup,
      data: {'email': email, 'password': password},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    return Account.fromJson(data);
  }

  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    return TokenPair.fromJson(data);
  }

  Future<TokenPair> refresh(String refreshToken) async {
    final response = await _apiClient.post(
      ApiEndpoints.refresh,
      data: {'refresh_token': refreshToken},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    return TokenPair.fromJson(data);
  }

  Future<void> logout() async {
    await _apiClient.post(ApiEndpoints.logout);
  }
}
