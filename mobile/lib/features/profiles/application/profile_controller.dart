import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/profiles/application/profile_providers.dart';
import 'package:mobile/features/profiles/data/models/profile_models.dart';
import 'package:mobile/features/profiles/data/profile_repository.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profiles = const [],
    this.errorMessage,
  });

  final ProfileStatus status;
  final List<Profile> profiles;
  final String? errorMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    List<Profile>? profiles,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profiles: profiles ?? this.profiles,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ProfileController extends Notifier<ProfileState> {
  late final ProfileRepository _repository;

  @override
  ProfileState build() {
    _repository = ref.read(profileRepositoryProvider);
    return const ProfileState();
  }

  Future<void> loadProfiles() async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true);

    try {
      final profiles = await _repository.listProfiles();
      state = ProfileState(status: ProfileStatus.loaded, profiles: profiles);
    } catch (error) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: _messageFromError(error),
      );
    }
  }

  /// Make the profile used most recently by a profile-scoped feature the
  /// active profile. The rest of the app already uses the first profile as
  /// its active-profile fallback, so keeping the selected profile first keeps
  /// those existing navigation paths profile-correct without introducing a
  /// second source of truth.
  void selectProfile(String profileId) {
    final index = state.profiles.indexWhere((profile) => profile.id == profileId);

    if (index <= 0) {
      return;
    }

    final selected = state.profiles[index];
    final profiles = <Profile>[
      selected,
      ...state.profiles.take(index),
      ...state.profiles.skip(index + 1),
    ];

    state = state.copyWith(profiles: profiles);
  }

  Future<bool> createProfile({required String name, String? avatarUrl}) async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true);

    try {
      final profile = await _repository.createProfile(
        name: name,
        avatarUrl: avatarUrl,
      );

      state = ProfileState(
        status: ProfileStatus.loaded,
        profiles: [...state.profiles, profile],
      );

      return true;
    } catch (error) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: _messageFromError(error),
      );
      return false;
    }
  }

  Future<bool> createProfileWithTryOnPhoto({
    required String name,
    required File file,
  }) async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true);

    try {
      final profile = await _repository.createProfile(name: name);
      final updatedProfile = await _repository.uploadTryOnPhoto(
        profileId: profile.id,
        file: file,
      );

      state = ProfileState(
        status: ProfileStatus.loaded,
        profiles: [...state.profiles, updatedProfile],
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: _messageFromError(error),
      );
      return false;
    }
  }

  Future<bool> uploadTryOnPhoto({
    required String profileId,
    required File file,
  }) async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true);

    try {
      final updatedProfile = await _repository.uploadTryOnPhoto(
        profileId: profileId,
        file: file,
      );

      final profiles = state.profiles
          .map(
            (profile) => profile.id == profileId ? updatedProfile : profile,
          )
          .toList();

      state = ProfileState(status: ProfileStatus.loaded, profiles: profiles);
      return true;
    } catch (error) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: _messageFromError(error),
      );
      return false;
    }
  }

  Future<bool> deleteProfile(String profileId) async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true);

    try {
      await _repository.deleteProfile(profileId);

      final profiles = state.profiles
          .where((profile) => profile.id != profileId)
          .toList();

      state = ProfileState(status: ProfileStatus.loaded, profiles: profiles);
      return true;
    } catch (error) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: _messageFromError(error),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _messageFromError(Object error) {
    return error.toString();
  }
}
