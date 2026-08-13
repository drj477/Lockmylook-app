import 'package:dio/dio.dart';

import 'package:mobile/core/network/dio_client.dart';

class ApiClient {
  ApiClient(this._dioClient);

  final DioClient _dioClient;

  Dio get dio => _dioClient.dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> postMultipart(
    String path, {
    required FormData data,
    Options? options,
  }) {
    return dio.post(path, data: data, options: options);
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return dio.put(path, data: data, options: options);
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return dio.patch(path, data: data, options: options);
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return dio.delete(path, data: data, options: options);
  }
}
