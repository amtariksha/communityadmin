import 'package:community_admin/services/api_client.dart';

class InvoiceService {
  final ApiClient _api;

  InvoiceService(this._api);

  Future<Map<String, dynamic>> getInvoices({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) params['status'] = status;

    final response = await _api.get<Map<String, dynamic>>(
      '/invoices',
      queryParameters: params,
    );
    return response.data!;
  }

  Future<List<dynamic>> getInvoiceRules() async {
    final response = await _api.get<Map<String, dynamic>>('/invoices/rules');
    final data = response.data!;
    return (data['rules'] as List<dynamic>?) ??
        (data['items'] as List<dynamic>?) ??
        [];
  }

  Future<Map<String, dynamic>> generateInvoices(
    String ruleId,
    String invoiceDate,
  ) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/invoices/generate',
      data: {
        'rule_id': ruleId,
        'invoice_date': invoiceDate,
      },
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> postInvoices(List<String> invoiceIds) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/invoices/post',
      data: {'invoice_ids': invoiceIds},
    );
    return response.data!;
  }
}
