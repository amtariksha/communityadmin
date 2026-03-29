import 'package:community_admin/services/api_client.dart';

class AnnouncementService {
  final ApiClient _api;

  AnnouncementService(this._api);

  Future<Map<String, dynamic>> getAnnouncements({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/announcements',
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String body,
    required String category,
    required String priority,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/announcements',
      data: {
        'title': title,
        'body': body,
        'category': category,
        'priority': priority,
      },
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> publishAnnouncement(String id) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/announcements/$id/publish',
    );
    return response.data!;
  }
}
