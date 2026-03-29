import 'package:community_admin/services/api_client.dart';

class TicketService {
  final ApiClient _api;

  TicketService(this._api);

  Future<Map<String, dynamic>> getTickets({
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
      '/tickets',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> updateTicket(
    String id, {
    required String status,
  }) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/tickets/$id',
      data: {'status': status},
    );
    return response.data!;
  }
}
