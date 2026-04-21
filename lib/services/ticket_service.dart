import 'package:community_admin/services/api_client.dart';

class TicketService {
  final ApiClient _api;

  TicketService(this._api);

  Future<Map<String, dynamic>> getTickets({
    String? status,
    String? priority,
    String? category,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (priority != null && priority.isNotEmpty) params['priority'] = priority;
    if (category != null && category.isNotEmpty) params['category'] = category;

    final response = await _api.get<Map<String, dynamic>>(
      '/tickets',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> getTicket(String id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/tickets/$id');
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await _api.get<Map<String, dynamic>>('/tickets/stats');
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<List<String>> getCategories() async {
    final response =
        await _api.get<Map<String, dynamic>>('/tickets/categories');
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>> createTicket({
    required String category,
    required String subject,
    String? description,
    String? priority,
    String? unitId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/tickets',
      data: {
        'category': category,
        'subject': subject,
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority,
        if (unitId != null) 'unit_id': unitId,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTicket(
    String id, {
    String? status,
    String? priority,
    String? assignedTo,
    String? category,
  }) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/tickets/$id',
      data: {
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (category != null) 'category': category,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addComment(
    String ticketId, {
    required String message,
    bool isInternal = false,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/tickets/$ticketId/comments',
      data: {
        'message': message,
        'is_internal': isInternal,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }
}
