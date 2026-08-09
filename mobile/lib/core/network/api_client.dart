import 'package:dio/dio.dart';

import 'package:mobile/core/network/dio_client.dart';

class ApiClient {
  ApiClient(this._dioClient);

  final DioClient _dioClient;

  Dio get dio => _dioClient.dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> postMultipart(
    String path, {
    required FormData data,
  }) {
    return dio.post(path, data: data);
  }

  Future<Response<dynamic>> put(String path, {dynamic data}) {
    return dio.put(path, data: data);
  }

  Future<Response<dynamic>> patch(String path, {dynamic data}) {
    return dio.patch(path, data: data);
  }

  Future<Response<dynamic>> delete(String path, {dynamic data}) {
    return dio.delete(path, data: data);
  }
}
