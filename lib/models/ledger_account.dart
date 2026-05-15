/// Ledger account row, returned from `GET /ledger/accounts`.
class LedgerAccount {
  final String id;
  final String code;
  final String name;
  final String accountType; // asset | liability | income | expense | equity
  final String? groupId;
  final bool isActive;

  const LedgerAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.accountType,
    this.groupId,
    this.isActive = true,
  });

  factory LedgerAccount.fromJson(Map<String, dynamic> json) {
    return LedgerAccount(
      id: json['id'] as String,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      accountType: (json['account_type'] as String?) ?? '',
      groupId: json['group_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get displayLabel => code.isEmpty ? name : '$code · $name';
}
