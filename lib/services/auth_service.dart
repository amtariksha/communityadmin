import 'package:community_admin/services/api_client.dart';
import 'package:community_admin/services/auth_token_store.dart';
import 'package:dio/dio.dart';

/// QA #57 cookie-auth migration. Mirrors the resident + guard apps:
/// `verifyOtp` stores only the access token (the refresh is an
/// httpOnly cookie), `refresh` posts an empty body, `logout` hits
/// the new `/auth/logout` route and wipes the cookie jar.
class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<Map<String, dynamic>> sendOtp(
    String phone, {
    String channel = 'whatsapp',
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/send-otp',
      data: {'phone': phone, 'channel': channel},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      data: {'phone': phone, 'otp': otp},
    );
    final data = response.data!;
    final token = data['access_token'] as String? ?? data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      AuthTokenStore.instance.setAccessToken(token);
    }
    return data;
  }

  Future<Map<String, dynamic>> switchTenant(String tenantId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/switch-tenant',
      data: {'tenant_id': tenantId},
    );
    final data = response.data!;
    final token = data['access_token'] as String? ?? data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      AuthTokenStore.instance.setAccessToken(token);
    }
    return data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.get<Map<String, dynamic>>('/auth/me');
    return response.data!;
  }

  Future<bool> refresh() => _api.refresh();

  Future<void> logout() async {
    try {
      await _api.post<Map<String, dynamic>>('/auth/logout');
    } on DioException {
      // Best-effort server-side logout; local wipe below still runs.
    }
    AuthTokenStore.instance.clear();
    try {
      await _api.cookieJar.deleteAll();
    } catch (_) {
      // cookie jar may not be initialised in edge cases; ignore.
    }
  }
}
