import 'package:community_admin/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dashboard stats service.
///
/// The dedicated `/dashboard` endpoint is not yet implemented on the
/// backend. Until it ships, [getStats] aggregates counts from
/// existing tenant-scoped endpoints client-side using their pagination
/// `total` fields — single round-trip per stat with `limit=1`.
///
/// When the backend ships `/dashboard`, swap the fallback chain so
/// the dedicated endpoint takes precedence and the aggregation
/// becomes the offline-degrade path.
class DashboardService {
  final ApiClient _api;

  DashboardService(this._api);

  Future<Map<String, dynamic>> getStats() async {
    // Try the dedicated endpoint first — when backend ships it,
    // these results take precedence and we skip the aggregation.
    try {
      final response = await _api.get<Map<String, dynamic>>('/dashboard');
      final data = response.data;
      if (data != null && data.isNotEmpty) return data;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        // 404 → fall through to aggregation. Other errors propagate.
        rethrow;
      }
    }

    // Client-side aggregation. Fire counts in parallel.
    final results = await Future.wait<int>([
      _countFromList('/units', queryParameters: {'page': 1, 'limit': 1}),
      _countFromList('/invoices', queryParameters: {'page': 1, 'limit': 1}),
      _countFromList(
        '/invoices',
        queryParameters: {'page': 1, 'limit': 1, 'status': 'overdue'},
      ),
      _countFromList(
        '/invoices',
        queryParameters: {'page': 1, 'limit': 1, 'status': 'paid'},
      ),
      _countFromList(
        '/gate/visitors',
        queryParameters: {'page': 1, 'limit': 1},
      ),
      _countFromList(
        '/gate/parcels',
        queryParameters: {'page': 1, 'limit': 1},
      ),
    ]);

    return <String, dynamic>{
      'total_units': results[0],
      'occupied': results[0], // backend doesn't expose vacancy yet
      'total_invoices': results[1],
      'overdue_invoices': results[2],
      'paid_invoices': results[3],
      'visitors_today': results[4],
      'pending_parcels': results[5],
    };
  }

  Future<int> _countFromList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      final raw = response.data ?? const <String, dynamic>{};
      final total = (raw['total'] as int?);
      if (total != null) return total;
      final items = (raw['data'] as List<dynamic>?) ??
          (raw['items'] as List<dynamic>?) ??
          const [];
      return items.length;
    } catch (e) {
      if (kDebugMode) debugPrint('[dashboard] count $path failed: $e');
      return 0;
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
