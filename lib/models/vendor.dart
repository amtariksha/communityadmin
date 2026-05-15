/// Vendor master row. Mirrors the `vendors` table.
class Vendor {
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstin;
  final String? pan;
  final String? legalName;
  final String? stateCode;
  final String? bankName;
  final String? bankBranch;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? tdsSection;
  final num? tdsRate;
  final String? ledgerAccountId;
  final bool isActive;

  const Vendor({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.pan,
    this.legalName,
    this.stateCode,
    this.bankName,
    this.bankBranch,
    this.bankAccountNumber,
    this.bankIfsc,
    this.tdsSection,
    this.tdsRate,
    this.ledgerAccountId,
    this.isActive = true,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      gstin: json['gstin'] as String?,
      pan: json['pan'] as String?,
      legalName: json['legal_name'] as String?,
      stateCode: json['state_code'] as String?,
      bankName: json['bank_name'] as String?,
      bankBranch: json['bank_branch'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankIfsc: json['bank_ifsc'] as String?,
      tdsSection: json['tds_section'] as String?,
      tdsRate: json['tds_rate'] is String
          ? num.tryParse(json['tds_rate'] as String)
          : json['tds_rate'] as num?,
      ledgerAccountId: json['ledger_account_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Build the JSON body for POST/PATCH /vendors. Omits null fields so
  /// PATCH only sends the keys the caller actually wants to update.
  Map<String, dynamic> toCreateJson() {
    final m = <String, dynamic>{
      'name': name,
      if (contactPerson != null) 'contact_person': contactPerson,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (gstin != null) 'gstin': gstin,
      if (pan != null) 'pan': pan,
      if (legalName != null) 'legal_name': legalName,
      if (stateCode != null) 'state_code': stateCode,
      if (bankName != null) 'bank_name': bankName,
      if (bankBranch != null) 'bank_branch': bankBranch,
      if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
      if (bankIfsc != null) 'bank_ifsc': bankIfsc,
      if (tdsSection != null) 'tds_section': tdsSection,
      if (tdsRate != null) 'tds_rate': tdsRate,
    };
    return m;
  }
}
