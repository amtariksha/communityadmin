import 'package:community_admin/services/api_client.dart';

class UtilityService {
  final ApiClient _api;

  UtilityService(this._api);

  Future<List<Map<String, dynamic>>> getMeters({
    String? unitId,
    String? meterType,
  }) async {
    final params = <String, dynamic>{};
    if (unitId != null) params['unit_id'] = unitId;
    if (meterType != null) params['meter_type'] = meterType;
    final response = await _api.get<Map<String, dynamic>>(
      '/utilities/meters',
      queryParameters: params,
    );
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getReadings(
    String meterId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/utilities/readings/$meterId',
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> submitReading({
    required String meterId,
    required double readingValue,
    required String readingDate, // yyyy-MM-dd
    String? imageUrl,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/utilities/readings',
      data: {
        'meter_id': meterId,
        'reading_value': readingValue,
        'reading_date': readingDate,
        if (imageUrl != null) 'reading_image_url': imageUrl,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStats() async {
    final response =
        await _api.get<Map<String, dynamic>>('/utilities/stats');
    return response.data!['data'] as Map<String, dynamic>;
  }
}
