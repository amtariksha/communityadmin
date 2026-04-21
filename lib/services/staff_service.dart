import 'package:community_admin/services/api_client.dart';

class StaffService {
  final ApiClient _api;

  StaffService(this._api);

  // --- Employees ---

  Future<Map<String, dynamic>> getEmployees({
    String? staffType,
    bool? isActive,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (staffType != null) params['staff_type'] = staffType;
    if (isActive != null) params['is_active'] = isActive.toString();

    final response = await _api.get<Map<String, dynamic>>(
      '/staff/employees',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> getEmployee(String id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/staff/employees/$id');
    return response.data!['data'] as Map<String, dynamic>;
  }

  // --- Shifts ---

  Future<List<Map<String, dynamic>>> getShifts() async {
    final response = await _api.get<Map<String, dynamic>>('/staff/shifts');
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  // --- Attendance ---

  Future<List<Map<String, dynamic>>> getAttendance({
    String? staffId,
    String? gateId,
    String? date,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (staffId != null) params['staff_id'] = staffId;
    if (gateId != null) params['gate_id'] = gateId;
    if (date != null) params['date'] = date;

    final response = await _api.get<Map<String, dynamic>>(
      '/staff/attendance',
      queryParameters: params,
    );
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  // --- Leaves ---

  Future<List<Map<String, dynamic>>> getLeaves({
    String? staffId,
    String? status,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (staffId != null) params['staff_id'] = staffId;
    if (status != null) params['status'] = status;

    final response = await _api.get<Map<String, dynamic>>(
      '/staff/leaves',
      queryParameters: params,
    );
    final list = response.data!['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> approveLeave(String id, {String? comments}) async {
    await _api.patch<Map<String, dynamic>>(
      '/staff/leaves/$id/approve',
      data: comments != null ? {'comments': comments} : {},
    );
  }

  Future<void> rejectLeave(String id, {required String reason}) async {
    await _api.patch<Map<String, dynamic>>(
      '/staff/leaves/$id/reject',
      data: {'reason': reason},
    );
  }
}
