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

  Future<Map<String, dynamic>> getUnitDetail(String unitId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/units/$unitId/detail',
    );
    return response.data!;
  }

  Future<List<dynamic>> getMembers(String unitId) async {
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
    String? moveInDate,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'name': name,
      'member_type': memberType,
    };
    if (moveInDate != null) body['move_in_date'] = moveInDate;

    final response = await _api.post<Map<String, dynamic>>(
      '/units/$unitId/members',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> updateMember(
    String unitId,
    String memberId, {
    String? name,
    String? phone,
    String? email,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;

    final response = await _api.patch<Map<String, dynamic>>(
      '/units/$unitId/members/$memberId',
      data: body,
    );
    return response.data!;
  }

  Future<void> removeMember(String unitId, String memberId) async {
    await _api.delete<Map<String, dynamic>>(
      '/units/$unitId/members/$memberId',
    );
  }

  Future<Map<String, dynamic>> transferOwnership(
    String unitId, {
    required String name,
    required String phone,
    String? email,
    String? moveInDate,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
    };
    if (email != null) body['email'] = email;
    if (moveInDate != null) body['move_in_date'] = moveInDate;

    final response = await _api.post<Map<String, dynamic>>(
      '/units/$unitId/transfer-ownership',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> disconnectTenant(String unitId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/units/$unitId/disconnect-tenant',
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> getMemberDirectory({
    String? search,
    String? memberType,
    String? block,
    int? page,
    int? limit,
  }) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (memberType != null && memberType.isNotEmpty) {
      params['member_type'] = memberType;
    }
    if (block != null && block.isNotEmpty) params['block'] = block;
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;

    final response = await _api.get<Map<String, dynamic>>(
      '/units/directory/members',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> getOccupancyReport() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/units/occupancy/report',
    );
    return response.data!;
  }
}
