import 'package:community_admin/services/api_client.dart';

class VotingService {
  final ApiClient _api;

  VotingService(this._api);

  Future<List<Map<String, dynamic>>> getPolls({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final response = await _api.get<Map<String, dynamic>>(
      '/voting/polls',
      queryParameters: params,
    );
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getPoll(String id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/voting/polls/$id');
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closePoll(String id) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/voting/polls/$id/close',
    );
    return response.data!['data'] as Map<String, dynamic>;
  }
}
