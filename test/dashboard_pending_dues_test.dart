// Pending dues on the dashboard sums the overdue invoices. `GET /invoices`
// refuses a page over 100 rows with a 400, so the sum used to read
// `limit=200` and always showed "N/A". It now reads pages of 100.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_admin/services/api_client.dart';
import 'package:community_admin/services/dashboard_service.dart';

const _listCap = 100;

/// Serves the dashboard's GETs like the API: no `/dashboard` route (404),
/// `/invoices` refuses a limit over the list cap, every count is 0.
class _FakeApi implements ApiClient {
  final int overdueCount;
  final List<Map<String, dynamic>> invoiceQueries = [];
  _FakeApi(this.overdueCount);

  Response<T> _ok<T>(String path, Object body) => Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: body as T,
      );

  DioException _status(String path, int code) {
    final options = RequestOptions(path: path);
    return DioException(
      requestOptions: options,
      response: Response<dynamic>(requestOptions: options, statusCode: code),
    );
  }

  Map<String, dynamic> _overduePage(int page, int limit) {
    final start = (page - 1) * limit;
    final count = (overdueCount - start).clamp(0, limit);
    final rows = List.generate(count, (_) => {'balance': '10.50'});
    return {'data': rows, 'total': overdueCount};
  }

  @override
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters}) async {
    if (path == '/dashboard') throw _status(path, 404);
    if (path == '/units/occupancy/report') {
      return _ok<T>(path, {'data': <String, dynamic>{}});
    }
    final query = queryParameters ?? const <String, dynamic>{};
    final limit = int.parse('${query['limit'] ?? 25}');
    if (path == '/invoices') invoiceQueries.add(query);
    if (limit > _listCap) throw _status(path, 400);
    if (path == '/invoices' && query['status'] == 'overdue' && limit > 1) {
      return _ok<T>(path, _overduePage(int.parse('${query['page']}'), limit));
    }
    return _ok<T>(path, {'data': <dynamic>[], 'total': 0});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('sums every overdue invoice across pages of 100', () async {
    final api = _FakeApi(250);
    final stats = await DashboardService(api).getStats();

    expect(stats['pending_dues'], closeTo(250 * 10.5, 0.001));
    for (final query in api.invoiceQueries) {
      expect(int.parse('${query['limit']}'), lessThanOrEqualTo(_listCap));
    }
  });

  test('a short list is one request', () async {
    final api = _FakeApi(3);
    final stats = await DashboardService(api).getStats();

    expect(stats['pending_dues'], closeTo(31.5, 0.001));
    final pages = api.invoiceQueries.where((q) => q['limit'] == _listCap);
    expect(pages.length, 1);
  });

  test('1,000 or more overdue invoices show N/A, not a partial sum', () async {
    final stats = await DashboardService(_FakeApi(1200)).getStats();

    expect(stats['pending_dues'], isNull);
  });
}
