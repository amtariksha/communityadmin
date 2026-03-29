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
    return response.data!;
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
    return response.data!;
  }

  Future<Map<String, dynamic>> collectParcel(String id) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/gate/parcels/$id/collect',
    );
    return response.data!;
  }
}
