import 'package:community_admin/services/api_client.dart';

class AnnouncementService {
  final ApiClient _api;

  AnnouncementService(this._api);

  Future<Map<String, dynamic>> getAnnouncements({
    int page = 1,
    int limit = 25,
    String? category,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (category != null && category.isNotEmpty) params['category'] = category;

    final response = await _api.get<Map<String, dynamic>>(
      '/announcements',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> getAnnouncement(String id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/announcements/$id');
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String body,
    String category = 'general',
    String priority = 'normal',
    String targetAudience = 'all',
    bool publishNow = false,
    bool isPinned = false,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/announcements',
      data: {
        'title': title,
        'body': body,
        'category': category,
        'priority': priority,
        'target_audience': targetAudience,
        'publish_now': publishNow,
        'is_pinned': isPinned,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAnnouncement(
    String id, {
    String? title,
    String? body,
    String? category,
    String? priority,
    bool? isPinned,
  }) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/announcements/$id',
      data: {
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (category != null) 'category': category,
        if (priority != null) 'priority': priority,
        if (isPinned != null) 'is_pinned': isPinned,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> publishAnnouncement(String id) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/announcements/$id/publish',
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<void> deleteAnnouncement(String id) async {
    await _api.delete<Map<String, dynamic>>('/announcements/$id');
  }
}
