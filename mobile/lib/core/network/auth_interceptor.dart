import 'package:dio/dio.dart';

import 'package:mobile/core/constants/api_constants.dart';
import 'package:mobile/core/storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage, this._dio);

  final SecureStorage _secureStorage;
  final Dio _dio;

  static const _publicAuthPaths = <String>{
    '/auth/signup',
    '/auth/login',
    '/auth/refresh',
    '/auth/logout',
  };

  static const _retryKey = '_auth_retry';

  bool _isRefreshing = false;
  Future<String?>? _refreshFuture;

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

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;

    if (_isPublicAuthRequest(options)) {
      handler.next(err);
      return;
    }

    if (options.extra[_retryKey] == true) {
      await _secureStorage.clearTokens();
      handler.next(err);
      return;
    }

    try {
      final newAccessToken = await _refreshAccessToken();

      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _secureStorage.clearTokens();
        handler.next(err);
        return;
      }

      options.extra[_retryKey] = true;
      options.headers['Authorization'] = 'Bearer $newAccessToken';

      final response = await _dio.fetch(options);

      handler.resolve(response);
    } catch (_) {
      await _secureStorage.clearTokens();
      handler.next(err);
    }
  }

  Future<String?> _refreshAccessToken() async {
    if (_isRefreshing && _refreshFuture != null) {
      return _refreshFuture;
    }

    _isRefreshing = true;

    final future = _performRefresh();

    _refreshFuture = future;

    try {
      return await future;
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
    }
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _secureStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final response = await refreshDio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    final accessToken = data['access_token'] as String;
    final newRefreshToken = data['refresh_token'] as String;

    await _secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
    );

    return accessToken;
  }

  bool _isPublicAuthRequest(RequestOptions options) {
    final path = options.path;

    return _publicAuthPaths.any(
      (publicPath) => path == publicPath || path.endsWith(publicPath),
    );
  }
}
