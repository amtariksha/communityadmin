import 'package:community_admin/models/ledger_account.dart';
import 'package:community_admin/services/api_client.dart';

/// Wraps `GET /ledger/accounts` for the account-picker widgets used
/// in the bill form (expense, payable) and the payment form (bank).
class LedgerService {
  final ApiClient _api;
  LedgerService(this._api);

  /// List accounts, optionally constrained by `accountType` (one of
  /// `asset|liability|income|expense|equity`) or a free-text `search`.
  /// Backend returns `{ data: [...], total: N }`.
  Future<List<LedgerAccount>> listAccounts({
    String? accountType,
    String? search,
    int page = 1,
    int limit = 200,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'is_active': 'true',
    };
    if (accountType != null && accountType.isNotEmpty) {
      params['account_type'] = accountType;
    }
    if (search != null && search.isNotEmpty) params['search'] = search;

    final res = await _api.get<Map<String, dynamic>>(
      '/ledger/accounts',
      queryParameters: params,
    );
    final raw = res.data ?? const <String, dynamic>{};
    final list = (raw['data'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => LedgerAccount.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
