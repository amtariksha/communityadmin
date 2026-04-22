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

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
    this.selectedTenantId,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    User? user,
    String? error,
    String? selectedTenantId,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
      selectedTenantId: selectedTenantId ?? this.selectedTenantId,
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
      final token = await _storage.read(key: AppConstants.tokenKey);
      final userJson = await _storage.read(key: AppConstants.userKey);
      final tenantId = await _storage.read(key: AppConstants.tenantKey);

      if (token != null && userJson != null) {
        final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);

        // main() pre-seeds credentials; re-assert here so the notifier
        // and ApiClient never disagree after a hot reload.
        _ref.read(apiClientProvider).setCredentials(token, tenantId);

        state = AuthState(
          isAuthenticated: true,
          user: user,
          selectedTenantId: tenantId,
        );
      } else {
        _ref.read(apiClientProvider).clearCredentials();
        state = const AuthState();
      }
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

      final token = data['token'] as String? ?? data['access_token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (token == null || userData == null) {
        throw Exception('Invalid response from server');
      }

      final user = User.fromJson(userData);

      await _storage.write(key: AppConstants.tokenKey, value: token);
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

      // Seed the in-memory credentials on ApiClient BEFORE flipping
      // state. Router will redirect to dashboard and dashboard
      // providers will immediately fire API calls — they need the
      // Authorization header present on the very first request.
      _ref.read(apiClientProvider).setCredentials(token, tenantId);

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
