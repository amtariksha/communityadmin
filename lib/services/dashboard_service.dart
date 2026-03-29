import 'package:community_admin/services/api_client.dart';

class DashboardService {
  final ApiClient _api;

  DashboardService(this._api);

  Future<Map<String, dynamic>> getStats() async {
    final response = await _api.get<Map<String, dynamic>>('/dashboard');
    return response.data!;
  }

  Future<List<dynamic>> getRecentActivity() async {
    final response = await _api.get<Map<String, dynamic>>('/dashboard/activity');
    final data = response.data!;
    return (data['items'] as List<dynamic>?) ?? [];
  }
}
