import 'package:community_admin/services/api_client.dart';

class GateService {
  final ApiClient _api;

  GateService(this._api);

  Future<Map<String, dynamic>> getVisitors({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) params['status'] = status;

    final response = await _api.get<Map<String, dynamic>>(
      '/gate/visitors',
      queryParameters: params,
    );
    final raw = response.data ?? const <String, dynamic>{};
    final items = (raw['data'] as List<dynamic>?) ??
        (raw['items'] as List<dynamic>?) ??
        (raw['visitors'] as List<dynamic>?) ??
        const <dynamic>[];
    final total = (raw['total'] as int?) ?? items.length;
    return <String, dynamic>{'items': items, 'total': total};
  }

  Future<Map<String, dynamic>> checkInVisitor(String id) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/gate/visitors/$id/check-in',
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> checkOutVisitor(String id) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/gate/visitors/$id/check-out',
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> getParcels({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/gate/parcels',
      queryParameters: {'page': page, 'limit': limit},
    );
    final raw = response.data ?? const <String, dynamic>{};
    final items = (raw['data'] as List<dynamic>?) ??
        (raw['items'] as List<dynamic>?) ??
        (raw['parcels'] as List<dynamic>?) ??
        const <dynamic>[];
    final total = (raw['total'] as int?) ?? items.length;
    return <String, dynamic>{'items': items, 'total': total};
  }

  Future<Map<String, dynamic>> collectParcel(
    String id, {
    required String collectedByName,
  }) async {
    // Backend .refine() rejects an empty body — one of
    // collected_by_name / collected_by_user_id is required.
    final response = await _api.patch<Map<String, dynamic>>(
      '/gate/parcels/$id/collect',
      data: {'collected_by_name': collectedByName},
    );
    return response.data!;
  }
}
