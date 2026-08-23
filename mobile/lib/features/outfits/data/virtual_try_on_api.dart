import 'package:dio/dio.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/features/outfits/data/models/virtual_try_on_models.dart';

class VirtualTryOnApi {
  VirtualTryOnApi(this._apiClient);

  final ApiClient _apiClient;

  Future<VirtualTryOnResult> generate({
    required String profileId,
    required VirtualTryOnRequest request,
  }) async {
    final response = await _apiClient.dio.post(
      '${ApiEndpoints.profiles}/$profileId/try-on',
      data: request.toJson(),
      options: Options(
        receiveTimeout: const Duration(seconds: 300),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    return VirtualTryOnResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VirtualTryOnSaveResult> setSaved({
    required String profileId,
    required String resultId,
    required bool saved,
  }) async {
    final response = await _apiClient.dio.patch(
      '${ApiEndpoints.profiles}/$profileId/try-on/$resultId/save',
      queryParameters: {'saved': saved},
    );

    return VirtualTryOnSaveResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<VirtualTryOnResult>> history({required String profileId}) async {
    final response = await _apiClient.dio.get(
      '${ApiEndpoints.profiles}/$profileId/try-on/history',
    );

    return (response.data as List<dynamic>)
        .map((item) => VirtualTryOnResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete({required String profileId, required String resultId}) async {
    await _apiClient.dio.delete(
      '${ApiEndpoints.profiles}/$profileId/try-on/$resultId',
    );
  }

  Future<void> deleteAll({required String profileId}) async {
    await _apiClient.dio.delete(
      '${ApiEndpoints.profiles}/$profileId/try-on/cache',
    );
  }
}
