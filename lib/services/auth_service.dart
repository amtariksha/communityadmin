import 'package:community_admin/core/roles.dart';
import 'package:community_admin/models/user.dart';
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

    // QA Round 14 #14-5b — apply admin-app role filter to incoming
    // societies. If the user has zero allowlisted roles across all
    // their societies (e.g. resident-only or guard-only account),
    // signal `wrong_app_for_account` to the auth notifier. Defense
    // is purely client-side until D1 #14-1e ships server-side
    // X-App-Target filtering.
    final userData = data['user'] as Map<String, dynamic>?;
    if (userData != null) {
      final raw = userData['societies'] as List<dynamic>? ?? const [];
      final all = raw
          .map((s) => Society.fromJson(s as Map<String, dynamic>))
          .toList(growable: false);
      final filtered = filterSocietiesForAdminApp(all);
      if (all.isNotEmpty && filtered.isEmpty) {
        data['wrong_app_for_account'] = true;
      } else {
        // Replace the societies list with the filtered subset so
        // downstream User.fromJson + selectSociety only see the
        // admin-relevant entries.
        userData['societies'] =
            filtered.map((s) => s.toJson()).toList(growable: false);
      }
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
