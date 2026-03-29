import 'package:community_admin/services/api_client.dart';

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<Map<String, dynamic>> sendOtp(String phone, {String channel = 'whatsapp'}) async {
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
    return response.data!;
  }

  Future<Map<String, dynamic>> switchTenant(String tenantId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/switch-tenant',
      data: {'tenant_id': tenantId},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.get<Map<String, dynamic>>('/auth/me');
    return response.data!;
  }
}
