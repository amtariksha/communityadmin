import 'package:community_admin/models/ledger_account.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Async dropdown that fetches ledger accounts filtered by
/// [accountType] (e.g. `expense`, `liability`, `asset`).
///
/// Use for picking expense / payable / bank accounts on bill +
/// payment forms. Caches the fetched list for the widget lifetime;
/// `key` it by accountType if you need to refresh on type change.
class AccountPicker extends ConsumerStatefulWidget {
  final String accountType;
  final String? selectedId;
  final String label;
  final ValueChanged<LedgerAccount?> onChanged;
  final String? Function(String?)? validator;

  const AccountPicker({
    super.key,
    required this.accountType,
    required this.label,
    required this.onChanged,
    this.selectedId,
    this.validator,
  });

  @override
  ConsumerState<AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends ConsumerState<AccountPicker> {
  List<LedgerAccount> _accounts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await ref
          .read(ledgerServiceProvider)
          .listAccounts(accountType: widget.accountType);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Loading ${widget.label.toLowerCase()}…',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    if (_error != null) {
      return InkWell(
        onTap: _load,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Could not load ${widget.label.toLowerCase()} — tap to retry',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    LedgerAccount? selected;
    if (widget.selectedId != null) {
      for (final a in _accounts) {
        if (a.id == widget.selectedId) {
          selected = a;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<LedgerAccount>(
        // ignore: deprecated_member_use
        value: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
        ),
        items: _accounts
            .map(
              (a) => DropdownMenuItem<LedgerAccount>(
                value: a,
                child: Text(
                  a.displayLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: widget.onChanged,
        validator: widget.validator == null
            ? null
            : (v) => widget.validator!(v?.id),
      ),
    );
  }
}
