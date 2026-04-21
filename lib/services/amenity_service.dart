import 'package:community_admin/services/api_client.dart';

class AmenityService {
  final ApiClient _api;

  AmenityService(this._api);

  Future<List<Map<String, dynamic>>> getAmenities() async {
    final response = await _api.get<Map<String, dynamic>>('/amenities');
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getBookings({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final response = await _api.get<Map<String, dynamic>>(
      '/amenities/bookings',
      queryParameters: params,
    );
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> cancelBooking(String id, {String? reason}) async {
    await _api.post<Map<String, dynamic>>(
      '/amenities/bookings/$id/cancel',
      data: reason != null ? {'reason': reason} : {},
    );
  }
}
