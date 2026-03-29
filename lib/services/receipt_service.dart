import 'package:community_admin/services/api_client.dart';

class ReceiptService {
  final ApiClient _api;

  ReceiptService(this._api);

  Future<Map<String, dynamic>> getReceipts({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/receipts',
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> createReceipt({
    required String unitId,
    required double amount,
    required String mode,
    String? referenceNumber,
    required String receiptDate,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/receipts',
      data: {
        'unit_id': unitId,
        'amount': amount,
        'mode': mode,
        if (referenceNumber != null) 'reference_number': referenceNumber,
        'receipt_date': receiptDate,
      },
    );
    return response.data!;
  }
}
