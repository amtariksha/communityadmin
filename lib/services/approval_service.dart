import 'package:community_admin/services/api_client.dart';

class ApprovalService {
  final ApiClient _api;

  ApprovalService(this._api);

  Future<Map<String, dynamic>> getRequests({
    String? requestType,
    String? status,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (requestType != null) params['request_type'] = requestType;
    if (status != null) params['status'] = status;

    final response = await _api.get<Map<String, dynamic>>(
      '/approvals',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<List<Map<String, dynamic>>> getMyPending() async {
    final response =
        await _api.get<Map<String, dynamic>>('/approvals/my-pending');
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getDetail(String id) async {
    final response = await _api.get<Map<String, dynamic>>('/approvals/$id');
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<void> approve(String id, {String? comments}) async {
    await _api.post<Map<String, dynamic>>(
      '/approvals/$id/approve',
      data: comments != null ? {'comments': comments} : {},
    );
  }

  Future<void> reject(String id, {required String reason}) async {
    await _api.post<Map<String, dynamic>>(
      '/approvals/$id/reject',
      data: {'reason': reason},
    );
  }
}
