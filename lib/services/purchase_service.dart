import 'package:community_admin/models/vendor_bill.dart';
import 'package:community_admin/services/api_client.dart';

class PurchaseService {
  final ApiClient _api;
  PurchaseService(this._api);

  // ---------------------------------------------------------------------------
  // Bills
  // ---------------------------------------------------------------------------

  Future<({List<VendorBill> items, int total})> listBills({
    String? status,
    String? vendorId,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (vendorId != null && vendorId.isNotEmpty) params['vendor_id'] = vendorId;
    if (startDate != null && startDate.isNotEmpty) {
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

    final res = await _api.get<Map<String, dynamic>>(
      '/purchases/bills',
      queryParameters: params,
    );
    final raw = res.data ?? const <String, dynamic>{};
    final list = (raw['data'] as List<dynamic>?) ??
        (raw['items'] as List<dynamic>?) ??
        const [];
    final items = list
        .map((e) => VendorBill.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final total = (raw['total'] as int?) ?? items.length;
    return (items: items, total: total);
  }

  Future<VendorBill> getBill(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/purchases/bills/$id');
    final raw = res.data!;
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    return VendorBill.fromJson(data);
  }

  /// Create a vendor bill. Required body fields per backend DTO:
  /// vendor_id, bill_date, total_amount, expense_account_id,
  /// payable_account_id. Optional: bill_number, due_date, gst_amount,
  /// tds_amount, narration.
  Future<VendorBill> createBill(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/purchases/bills',
      data: body,
    );
    final raw = res.data!;
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    return VendorBill.fromJson(data);
  }

  Future<VendorBill> updateBill(String id, Map<String, dynamic> body) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/purchases/bills/$id',
      data: body,
    );
    final raw = res.data!;
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    return VendorBill.fromJson(data);
  }

  /// Record a payment against a bill.
  Future<VendorPayment> payBill(
    String billId, {
    required String paymentDate,
    required num amount,
    num? tdsAmount,
    required String bankAccountId,
    required String paymentMode,
    String? referenceNumber,
  }) async {
    final body = <String, dynamic>{
      'payment_date': paymentDate,
      'amount': amount,
      'bank_account_id': bankAccountId,
      'payment_mode': paymentMode,
      if (tdsAmount != null) 'tds_amount': tdsAmount,
      if (referenceNumber != null && referenceNumber.isNotEmpty)
        'reference_number': referenceNumber,
    };
    final res = await _api.post<Map<String, dynamic>>(
      '/purchases/bills/$billId/pay',
      data: body,
    );
    final raw = res.data!;
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    return VendorPayment.fromJson(data);
  }

  Future<VendorBill> cancelBill(String billId, {required String reason}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/purchases/bills/$billId/cancel',
      data: {'reason': reason},
    );
    final raw = res.data!;
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    return VendorBill.fromJson(data);
  }

  /// Aging summary: per-vendor buckets (0-30, 31-60, 61-90, 91+ days).
  Future<List<Map<String, dynamic>>> aging() async {
    final res = await _api.get<Map<String, dynamic>>('/purchases/aging');
    final raw = res.data ?? const <String, dynamic>{};
    final list = (raw['data'] as List<dynamic>?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
