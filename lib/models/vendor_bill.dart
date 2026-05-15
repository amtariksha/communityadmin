/// Vendor bill row. Mirrors `vendor_bills` joined with `vendors`.
class VendorBill {
  final String id;
  final String vendorId;
  final String? vendorName;
  final String billNumber;
  final String billDate;
  final String? dueDate;
  final num subtotal;
  final num gstAmount;
  final num tdsAmount;
  final num totalAmount;
  final num amountPaid;
  final num balanceDue;
  final String status; // draft, received, partially_paid, paid, overdue, cancelled
  final String? narration;
  final String? expenseAccountId;
  final String? payableAccountId;
  final String? createdAt;

  const VendorBill({
    required this.id,
    required this.vendorId,
    this.vendorName,
    required this.billNumber,
    required this.billDate,
    this.dueDate,
    this.subtotal = 0,
    this.gstAmount = 0,
    this.tdsAmount = 0,
    required this.totalAmount,
    this.amountPaid = 0,
    this.balanceDue = 0,
    required this.status,
    this.narration,
    this.expenseAccountId,
    this.payableAccountId,
    this.createdAt,
  });

  factory VendorBill.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic v) =>
        v == null ? 0 : (v is num ? v : (num.tryParse(v.toString()) ?? 0));
    return VendorBill(
      id: json['id'] as String,
      vendorId: (json['vendor_id'] as String?) ?? '',
      vendorName: json['vendor_name'] as String?,
      billNumber: (json['bill_number'] as String?) ?? '',
      billDate: (json['bill_date'] as String?) ?? '',
      dueDate: json['due_date'] as String?,
      subtotal: parseNum(json['subtotal']),
      gstAmount: parseNum(json['gst_amount']),
      tdsAmount: parseNum(json['tds_amount']),
      totalAmount: parseNum(json['total_amount']),
      amountPaid: parseNum(json['amount_paid']),
      balanceDue: parseNum(json['balance_due']),
      status: (json['status'] as String?) ?? 'draft',
      narration: json['narration'] as String?,
      expenseAccountId: json['expense_account_id'] as String?,
      payableAccountId: json['payable_account_id'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Vendor payment row. Mirrors `vendor_payments`.
class VendorPayment {
  final String id;
  final String? vendorBillId;
  final String paymentDate;
  final num amount;
  final num tdsAmount;
  final String paymentMode; // cheque, neft, rtgs, upi, cash, dd
  final String? referenceNumber;
  final String? bankAccountId;
  final String? notes;

  const VendorPayment({
    required this.id,
    this.vendorBillId,
    required this.paymentDate,
    required this.amount,
    this.tdsAmount = 0,
    required this.paymentMode,
    this.referenceNumber,
    this.bankAccountId,
    this.notes,
  });

  factory VendorPayment.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic v) =>
        v == null ? 0 : (v is num ? v : (num.tryParse(v.toString()) ?? 0));
    return VendorPayment(
      id: json['id'] as String,
      vendorBillId: json['vendor_bill_id'] as String?,
      paymentDate: (json['payment_date'] as String?) ?? '',
      amount: parseNum(json['amount']),
      tdsAmount: parseNum(json['tds_amount']),
      paymentMode: (json['payment_mode'] as String?) ?? 'cash',
      referenceNumber: json['reference_number'] as String?,
      bankAccountId: json['bank_account_id'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

const List<String> kPaymentModes = [
  'cheque',
  'neft',
  'rtgs',
  'upi',
  'cash',
  'dd',
];
