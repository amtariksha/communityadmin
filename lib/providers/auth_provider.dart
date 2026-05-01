import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:community_admin/config/constants.dart';
import 'package:community_admin/models/user.dart';
import 'package:community_admin/providers/service_providers.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final User? user;
  final String? error;
  final String? selectedTenantId;

  /// Set when `verifyOtp` returns successfully but the user has zero
  /// admin-allowlisted roles across all their societies. Drives the
  /// `/wrong-app` redirect in `router.dart`. Transient — never
  /// persisted; cleared on logout. (QA Round 14 #14-5b)
  final bool wrongApp;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
    this.selectedTenantId,
    this.wrongApp = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    User? user,
    String? error,
    String? selectedTenantId,
    bool? wrongApp,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
      selectedTenantId: selectedTenantId ?? this.selectedTenantId,
      wrongApp: wrongApp ?? this.wrongApp,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthNotifier(this._ref) : super(const AuthState()) {
    _loadSavedAuth();
  }

  Future<void> _loadSavedAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      // QA #57 — access token no longer on disk. Read only user +
      // tenant, then exchange the refresh cookie for a new access
      // token via `AuthService.refresh()`.
      final userJson = await _storage.read(key: AppConstants.userKey);
      final tenantId = await _storage.read(key: AppConstants.tenantKey);

      if (userJson == null) {
        _ref.read(apiClientProvider).clearCredentials();
        state = const AuthState();
        return;
      }

      final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _ref.read(apiClientProvider).updateTenantId(tenantId);

      final refreshed =
          await _ref.read(authServiceProvider).refresh();
      if (!refreshed) {
        await _storage.delete(key: AppConstants.userKey);
        _ref.read(apiClientProvider).clearCredentials();
        state = const AuthState();
        return;
      }

      state = AuthState(
        isAuthenticated: true,
        user: user,
        selectedTenantId: tenantId,
      );
    } catch (e) {
      _ref.read(apiClientProvider).clearCredentials();
      state = const AuthState();
    }
  }

  Future<bool> sendOtp(String phone, {String channel = 'whatsapp'}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authService = _ref.read(authServiceProvider);
      await authService.sendOtp(phone, channel: channel);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authService = _ref.read(authServiceProvider);
      final data = await authService.verifyOtp(phone, otp);

      // QA Round 14 #14-5b — service signals when the account has no
      // admin-allowlisted roles. Flip auth state to `wrongApp` so the
      // router pushes /wrong-app. Treat this as authenticated so
      // logout from /wrong-app cleans up correctly.
      if (data['wrong_app_for_account'] == true) {
        final userData = data['user'] as Map<String, dynamic>?;
        final user = userData != null ? User.fromJson(userData) : null;
        state = AuthState(
          isAuthenticated: true,
          user: user,
          wrongApp: true,
        );
        return true;
      }

      final token = data['token'] as String? ?? data['access_token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (token == null || userData == null) {
        throw Exception('Invalid response from server');
      }

      final user = User.fromJson(userData);

      // QA #57 — access token lives only in AuthTokenStore (populated
      // in AuthService.verifyOtp above). We keep user + tenant on
      // disk for UI restoration across launches.
      await _storage.write(
        key: AppConstants.userKey,
        value: jsonEncode(user.toJson()),
      );

      // Auto-select first society if only one
      String? tenantId;
      if (user.societies.length == 1) {
        tenantId = user.societies.first.id;
        await _storage.write(key: AppConstants.tenantKey, value: tenantId);
      }

      _ref.read(apiClientProvider).updateTenantId(tenantId);

      state = AuthState(
        isAuthenticated: true,
        user: user,
        selectedTenantId: tenantId,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  Future<void> selectSociety(String tenantId) async {
    await _storage.write(key: AppConstants.tenantKey, value: tenantId);
    _ref.read(apiClientProvider).updateTenantId(tenantId);
    state = state.copyWith(selectedTenantId: tenantId);
  }

  Future<void> logout() async {
    // QA #57 — server-side + client-side logout. Hit /auth/logout so
    // the server drops the httpOnly refresh cookie; AuthService
    // wipes the cookie jar on disk. Then clear in-memory access
    // token + secure-storage user/tenant cache.
    try {
      await _ref.read(authServiceProvider).logout();
    } catch (_) {
      // Best-effort; local wipe still runs.
    }
    _ref.read(apiClientProvider).clearCredentials();
    await _storage.deleteAll();
    state = const AuthState();
  }

  String _extractError(dynamic e) {
    if (e.toString().contains('DioException')) {
      return 'Network error. Please try again.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
