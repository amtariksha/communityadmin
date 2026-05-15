import 'package:community_admin/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dashboard stats service.
///
/// QA #476 — `/dashboard` endpoint is not yet implemented on the
/// backend (returns 404). Until it ships, `getStats` returns an empty
/// map on 404 instead of throwing so the home screen renders a clean
/// welcome state. A non-404 error (network, 5xx) still propagates so
/// the user sees a real failure indicator.
class DashboardService {
  final ApiClient _api;

  DashboardService(this._api);

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _api.get<Map<String, dynamic>>('/dashboard');
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('[dashboard] /dashboard not yet implemented; empty state');
        }
        return const <String, dynamic>{};
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getRecentActivity() async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>('/dashboard/activity');
      final data = response.data!;
      return (data['items'] as List<dynamic>?) ?? [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    }
  }
}
