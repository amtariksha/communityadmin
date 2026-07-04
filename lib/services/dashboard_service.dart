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

    // Client-side aggregation. Fire the independent fetches in parallel.
    final occupancyFuture = _fetchOccupancy();
    final pendingDuesFuture = _sumOverdueBalances();
    final openTicketsFuture = _countOpenTickets();

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

    final occupancy = await occupancyFuture;
    final pendingDues = await pendingDuesFuture;
    final openTickets = await openTicketsFuture;

    return <String, dynamic>{
      'total_units': results[0],
      // Real occupancy percentage (occupied vs total units), or null →
      // rendered as "N/A" rather than a misleading raw unit count.
      'occupied_percent': occupancy,
      'total_invoices': results[1],
      'overdue_invoices': results[2],
      'paid_invoices': results[3],
      'visitors_today': results[4],
      'pending_parcels': results[5],
      // Sum of outstanding balances on overdue invoices; null → "N/A".
      'pending_dues': pendingDues,
      'open_tickets': openTickets,
    };
  }

  /// Occupancy as a whole-number percentage from
  /// `/units/occupancy/report`. Returns null when the report is
  /// unavailable or has no units, so the UI shows "N/A".
  Future<int?> _fetchOccupancy() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/units/occupancy/report',
      );
      final raw = response.data ?? const <String, dynamic>{};
      final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
      final total = _asNum(data['total_units'] ?? data['total']);
      final occupied = _asNum(data['occupied_units'] ?? data['occupied']);
      if (total == null || total <= 0 || occupied == null) return null;
      return ((occupied / total) * 100).round();
    } catch (e) {
      if (kDebugMode) debugPrint('[dashboard] occupancy failed: $e');
      return null;
    }
  }

  /// Page size used when summing overdue balances. If the fetched count
  /// reaches this cap the list is likely truncated and the sum would
  /// understate dues — we surface "N/A" instead (see [_sumOverdueBalances]).
  static const int _overduePageLimit = 200;

  /// Sum of outstanding balances across overdue invoices. Returns null
  /// when the list can't be fetched, so the UI shows "N/A" instead of
  /// a misleading ₹0. Also returns null when the page is full
  /// ([_overduePageLimit]) — a truncated page would silently understate
  /// pending dues, so an honest "N/A" beats a wrong-but-plausible figure.
  Future<double?> _sumOverdueBalances() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/invoices',
        queryParameters: {
          'page': 1,
          'limit': _overduePageLimit,
          'status': 'overdue',
        },
      );
      final raw = response.data ?? const <String, dynamic>{};
      final items = (raw['data'] as List<dynamic>?) ??
          (raw['items'] as List<dynamic>?) ??
          const <dynamic>[];
      // Full page → likely more overdue invoices than we fetched. Summing
      // only this page would understate dues, so surface it as unavailable.
      if (items.length >= _overduePageLimit) return null;
      var sum = 0.0;
      for (final item in items) {
        if (item is! Map) continue;
        // pg NUMERIC arrives as a String — parse at the boundary.
        final balance = _asNum(item['balance'] ??
                item['balance_due'] ??
                item['amount_due'] ??
                item['total_amount']) ??
            0;
        sum += balance;
      }
      return sum;
    } catch (e) {
      if (kDebugMode) debugPrint('[dashboard] pending dues failed: $e');
      return null;
    }
  }

  /// Count of open tickets from `/tickets` pagination `total`.
  Future<int> _countOpenTickets() async {
    return _countFromList(
      '/tickets',
      queryParameters: {'page': 1, 'limit': 1, 'status': 'open'},
    );
  }

  /// Parse a value that may be a JS number or a pg-NUMERIC String.
  double? _asNum(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
