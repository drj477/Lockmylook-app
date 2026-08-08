import 'package:dio/dio.dart';

import 'package:mobile/core/storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage);

  final SecureStorage _secureStorage;

  static const _publicAuthPaths = <String>{
    '/auth/signup',
    '/auth/login',
    '/auth/refresh',
    '/auth/logout',
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicAuthRequest(options)) {
      handler.next(options);
      return;
    }

    final accessToken = await _secureStorage.getAccessToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  bool _isPublicAuthRequest(RequestOptions options) {
    final path = options.path;

    return _publicAuthPaths.any(
      (publicPath) => path == publicPath || path.endsWith(publicPath),
    );
  }
}
