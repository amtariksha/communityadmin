import 'package:community_admin/models/vendor.dart';
import 'package:community_admin/services/api_client.dart';

class VendorService {
  final ApiClient _api;
  VendorService(this._api);

  Future<({List<Vendor> items, int total})> list({
    String? search,
    bool? isActive,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (isActive != null) params['is_active'] = isActive.toString();

    final res = await _api.get<Map<String, dynamic>>(
      '/vendors',
      queryParameters: params,
    );
    final raw = res.data ?? const <String, dynamic>{};
    final list = (raw['data'] as List<dynamic>?) ??
        (raw['items'] as List<dynamic>?) ??
        const [];
    final items = list
        .map((e) => Vendor.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final total = (raw['total'] as int?) ?? items.length;
    return (items: items, total: total);
  }

  Future<Vendor> get(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/vendors/$id');
    final raw = res.data!;
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    return Vendor.fromJson(data);
  }

  Future<Vendor> create(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/vendors',
      data: body,
    );
    final raw = res.data!;
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    return Vendor.fromJson(data);
  }

  Future<Vendor> update(String id, Map<String, dynamic> body) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/vendors/$id',
      data: body,
    );
    final raw = res.data!;
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    return Vendor.fromJson(data);
  }

  Future<void> deactivate(String id) async {
    await _api.delete<Map<String, dynamic>>('/vendors/$id');
  }
}
