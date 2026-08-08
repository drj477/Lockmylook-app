import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/auth/application/auth_providers.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';

enum AuthStatus { unauthenticated, loading, authenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.account,
    this.errorMessage,
  });

  final AuthStatus status;
  final Account? account;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    Account? account,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      account: account ?? this.account,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);
    return const AuthState();
  }

  Future<void> restoreSession() async {
    state = const AuthState(status: AuthStatus.loading);

    try {
      final hasSession = await _repository.hasSession();

      if (!hasSession) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      await _repository.refresh();

      state = const AuthState(status: AuthStatus.authenticated);
    } catch (_) {
      try {
        await _repository.clearLocalSession();
      } catch (_) {
        // Ignore cleanup failures during startup.
      }

      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = const AuthState(status: AuthStatus.loading);

    try {
      await _repository.login(email: email, password: password);

      state = const AuthState(status: AuthStatus.authenticated);

      return true;
    } catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _messageFromError(error),
      );

      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    state = const AuthState(status: AuthStatus.loading);

    try {
      final account = await _repository.signup(
        email: email,
        password: password,
      );

      state = AuthState(status: AuthStatus.unauthenticated, account: account);

      return true;
    } catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _messageFromError(error),
      );

      return false;
    }
  }

  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.loading);

    try {
      await _repository.logout();

      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _messageFromError(error),
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _messageFromError(Object error) {
    return error.toString();
  }
}
