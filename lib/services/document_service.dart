import 'package:community_admin/services/api_client.dart';

class DocumentService {
  final ApiClient _api;

  DocumentService(this._api);

  Future<Map<String, dynamic>> getDocuments({
    String? category,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (category != null) params['category'] = category;
    final response = await _api.get<Map<String, dynamic>>(
      '/documents',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<List<String>> getCategories() async {
    final response =
        await _api.get<Map<String, dynamic>>('/documents/categories');
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  Future<void> deleteDocument(String id) async {
    await _api.delete<Map<String, dynamic>>('/documents/$id');
  }
}
