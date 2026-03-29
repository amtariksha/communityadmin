import 'package:community_admin/services/api_client.dart';

class UnitService {
  final ApiClient _api;

  UnitService(this._api);

  Future<Map<String, dynamic>> getUnits({
    int page = 1,
    int limit = 20,
    String? block,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (block != null && block.isNotEmpty) params['block'] = block;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _api.get<Map<String, dynamic>>(
      '/units',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<List<dynamic>> getUnitMembers(String unitId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/units/$unitId/members',
    );
    final data = response.data!;
    return (data['members'] as List<dynamic>?) ??
        (data['items'] as List<dynamic>?) ??
        [];
  }

  Future<Map<String, dynamic>> addMember(
    String unitId, {
    required String phone,
    required String name,
    required String memberType,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/units/$unitId/members',
      data: {
        'phone': phone,
        'name': name,
        'member_type': memberType,
      },
    );
    return response.data!;
  }
}
