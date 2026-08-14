import 'dart:io';

import 'package:dio/dio.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/features/profiles/data/models/profile_models.dart';

class ProfileApi {
  ProfileApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Profile>> listProfiles() async {
    final response = await _apiClient.get(ApiEndpoints.profiles);

    final data = response.data as Map<String, dynamic>;
    final profiles = data['data'] as List<dynamic>;

    return profiles
        .map((item) => Profile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Profile> createProfile(ProfileCreateRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.profiles,
      data: request.toJson(),
    );

    final data = response.data as Map<String, dynamic>;

    return Profile.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Profile> uploadTryOnPhoto({
    required String profileId,
    required File file,
  }) async {
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'try-on-photo.jpg';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final response = await _apiClient.postMultipart(
      '${ApiEndpoints.profiles}/$profileId/try-on-photo',
      data: formData,
      options: Options(
        extra: {
          // Dio cannot safely replay a consumed MultipartFile stream after a
          // 401. AuthInterceptor uses these values to recreate the body.
          '_auth_retry_file_path': file.path,
          '_auth_retry_file_name': fileName,
        },
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    final envelope = response.data as Map<String, dynamic>;
    return Profile.fromJson(envelope['data'] as Map<String, dynamic>);
  }

  Future<Profile> getProfile(String profileId) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.profiles}/$profileId',
    );

    final data = response.data as Map<String, dynamic>;

    return Profile.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteProfile(String profileId) async {
    await _apiClient.delete('${ApiEndpoints.profiles}/$profileId');
  }
}
