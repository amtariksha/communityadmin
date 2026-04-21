double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class InvoiceOcrResult {
  final String? vendorName;
  final String? vendorGstin;
  final String? vendorPan;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? dueDate;
  final double? subtotal;
  final double? gstAmount;
  final double? totalAmount;
  final List<InvoiceLine> lineItems;
  final InvoiceBank? bankDetails;
  final String rawText;
  final double confidence;

  const InvoiceOcrResult({
    this.vendorName,
    this.vendorGstin,
    this.vendorPan,
    this.invoiceNumber,
    this.invoiceDate,
    this.dueDate,
    this.subtotal,
    this.gstAmount,
    this.totalAmount,
    this.lineItems = const [],
    this.bankDetails,
    this.rawText = '',
    this.confidence = 0,
  });

  factory InvoiceOcrResult.fromJson(Map<String, dynamic> json) {
    final items = (json['line_items'] as List<dynamic>? ?? [])
        .map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>))
        .toList();
    final bank = json['bank_details'] as Map<String, dynamic>?;
    return InvoiceOcrResult(
      vendorName: json['vendor_name']?.toString(),
      vendorGstin: json['vendor_gstin']?.toString(),
      vendorPan: json['vendor_pan']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      invoiceDate: json['invoice_date']?.toString(),
      dueDate: json['due_date']?.toString(),
      subtotal: _toDouble(json['subtotal']),
      gstAmount: _toDouble(json['gst_amount']),
      totalAmount: _toDouble(json['total_amount']),
      lineItems: items,
      bankDetails: bank == null ? null : InvoiceBank.fromJson(bank),
      rawText: json['raw_text']?.toString() ?? '',
      confidence: _toDouble(json['confidence']) ?? 0,
    );
  }
}

class InvoiceLine {
  final String description;
  final int? quantity;
  final double? rate;
  final double amount;
  final double? gstRate;

  const InvoiceLine({
    required this.description,
    this.quantity,
    this.rate,
    required this.amount,
    this.gstRate,
  });

  factory InvoiceLine.fromJson(Map<String, dynamic> json) => InvoiceLine(
        description: json['description']?.toString() ?? '',
        quantity: _toInt(json['quantity']),
        rate: _toDouble(json['rate']),
        amount: _toDouble(json['amount']) ?? 0,
        gstRate: _toDouble(json['gst_rate']),
      );
}

class InvoiceBank {
  final String? bankName;
  final String? accountNumber;
  final String? ifsc;

  const InvoiceBank({this.bankName, this.accountNumber, this.ifsc});

  factory InvoiceBank.fromJson(Map<String, dynamic> json) => InvoiceBank(
        bankName: json['bank_name']?.toString(),
        accountNumber: json['account_number']?.toString(),
        ifsc: json['ifsc']?.toString(),
      );
}

class MeterReadingOcrResult {
  final double? readingValue;
  final String? meterNumber;
  final String? unit;
  final double confidence;
  final String rawText;

  const MeterReadingOcrResult({
    this.readingValue,
    this.meterNumber,
    this.unit,
    this.confidence = 0,
    this.rawText = '',
  });

  factory MeterReadingOcrResult.fromJson(Map<String, dynamic> json) =>
      MeterReadingOcrResult(
        readingValue: _toDouble(json['reading_value']),
        meterNumber: json['meter_number']?.toString(),
        unit: json['unit']?.toString(),
        confidence: _toDouble(json['confidence']) ?? 0,
        rawText: json['raw_text']?.toString() ?? '',
      );
}

class IdDocumentOcrResult {
  final String documentType; // aadhaar | pan | passport | voter_id | driving_license | unknown
  final String? name;
  final String? documentNumber;
  final String? dateOfBirth;
  final String? gender;
  final String? address;
  final String? fatherName;
  final double confidence;
  final String rawText;

  const IdDocumentOcrResult({
    required this.documentType,
    this.name,
    this.documentNumber,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.fatherName,
    this.confidence = 0,
    this.rawText = '',
  });

  factory IdDocumentOcrResult.fromJson(Map<String, dynamic> json) =>
      IdDocumentOcrResult(
        documentType: json['document_type']?.toString() ?? 'unknown',
        name: json['name']?.toString(),
        documentNumber: json['document_number']?.toString(),
        dateOfBirth: json['date_of_birth']?.toString(),
        gender: json['gender']?.toString(),
        address: json['address']?.toString(),
        fatherName: json['father_name']?.toString(),
        confidence: _toDouble(json['confidence']) ?? 0,
        rawText: json['raw_text']?.toString() ?? '',
      );
}

class GenericOcrResult {
  final String text;
  final double confidence;

  const GenericOcrResult({required this.text, this.confidence = 0});

  factory GenericOcrResult.fromJson(Map<String, dynamic> json) =>
      GenericOcrResult(
        text: json['text']?.toString() ?? '',
        confidence: _toDouble(json['confidence']) ?? 0,
      );
}
