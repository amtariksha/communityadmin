import 'package:community_admin/config/theme.dart';
import 'package:community_admin/main.dart' show showRootSnackBar;
import 'package:community_admin/models/ledger_account.dart';
import 'package:community_admin/models/vendor_bill.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/widgets/account_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PurchaseDetailScreen extends ConsumerStatefulWidget {
  final String billId;
  const PurchaseDetailScreen({super.key, required this.billId});

  @override
  ConsumerState<PurchaseDetailScreen> createState() =>
      _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  VendorBill? _bill;
  bool _loading = true;
  String? _error;
  bool _changed = false;

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
      final b = await ref.read(purchaseServiceProvider).getBill(widget.billId);
      if (!mounted) return;
      setState(() {
        _bill = b;
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

  // ---------------------------------------------------------------------------
  // Pay
  // ---------------------------------------------------------------------------

  Future<void> _openPaySheet() async {
    if (_bill == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PaymentSheet(
        billId: widget.billId,
        balanceDue: _bill!.balanceDue,
      ),
    );
    if (result == true) {
      _changed = true;
      _load();
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel
  // ---------------------------------------------------------------------------

  Future<void> _cancel() async {
    final reasonCtl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'A reversal journal entry will be posted. This cannot be undone.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtl,
              decoration: const InputDecoration(
                  labelText: 'Reason *', isDense: true),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel bill',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final reason = reasonCtl.text.trim();
    if (reason.isEmpty) {
      showRootSnackBar('Reason is required');
      return;
    }
    try {
      await ref
          .read(purchaseServiceProvider)
          .cancelBill(widget.billId, reason: reason);
      if (!mounted) return;
      _changed = true;
      showRootSnackBar('Bill cancelled');
      _load();
    } catch (e) {
      showRootSnackBar('Cancel failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _changed) {
          // already popped
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Bill')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : _bill == null
                    ? const Center(child: Text('Not found'))
                    : _detailBody(_bill!),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _detailBody(VendorBill b) {
    final canPay = b.balanceDue > 0 && b.status != 'cancelled';
    final canCancel =
        b.status != 'cancelled' && b.status != 'paid' && b.amountPaid == 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('#${b.billNumber}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    _StatusBadge(status: b.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(b.vendorName ?? 'Vendor',
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                _kv('Bill date', _fmtDate(b.billDate)),
                _kv('Due date',
                    b.dueDate == null ? null : _fmtDate(b.dueDate!)),
                if (b.narration != null && b.narration!.isNotEmpty)
                  _kv('Narration', b.narration),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amounts',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _amount('Subtotal', b.subtotal),
                _amount('GST', b.gstAmount),
                _amount('TDS', b.tdsAmount),
                const Divider(),
                _amount('Total', b.totalAmount, bold: true),
                _amount('Paid', b.amountPaid, color: AppTheme.successColor),
                _amount('Balance', b.balanceDue,
                    bold: true,
                    color: b.balanceDue > 0
                        ? AppTheme.errorColor
                        : AppTheme.successColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (canPay)
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openPaySheet,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Record payment'),
            ),
          ),
        const SizedBox(height: 12),
        if (canCancel)
          OutlinedButton.icon(
            onPressed: _cancel,
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            label: const Text('Cancel bill',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
      ],
    );
  }

  String _fmtDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Widget _kv(String label, String? value) {
    final display = value == null || value.isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(child: Text(display)),
        ],
      ),
    );
  }

  Widget _amount(String label, num value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color,
              )),
          Text(
            '₹${NumberFormat('#,##0.00').format(value)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Color _color(String s) {
    switch (s) {
      case 'paid':
        return AppTheme.successColor;
      case 'overdue':
        return AppTheme.errorColor;
      case 'partially_paid':
        return AppTheme.warningColor;
      case 'cancelled':
        return Colors.grey;
      case 'received':
        return AppTheme.primaryColor;
      case 'draft':
      default:
        return Colors.grey;
    }
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final String billId;
  final num balanceDue;
  const _PaymentSheet({required this.billId, required this.balanceDue});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _tdsAmount = TextEditingController();
  final _reference = TextEditingController();

  DateTime _date = DateTime.now();
  String _mode = kPaymentModes.first;
  LedgerAccount? _bankAccount;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.balanceDue.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    _tdsAmount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bankAccount == null) {
      setState(() => _error = 'Please pick a bank/cash account');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(purchaseServiceProvider).payBill(
            widget.billId,
            paymentDate: DateFormat('yyyy-MM-dd').format(_date),
            amount: num.tryParse(_amount.text.trim()) ?? 0,
            tdsAmount: _tdsAmount.text.trim().isEmpty
                ? null
                : num.tryParse(_tdsAmount.text.trim()),
            bankAccountId: _bankAccount!.id,
            paymentMode: _mode,
            referenceNumber: _reference.text.trim().isEmpty
                ? null
                : _reference.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Record payment',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)),
                ),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Payment date *', isDense: true),
                  child:
                      Text(DateFormat('dd MMM yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  isDense: true,
                  prefixText: '₹ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = num.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Must be > 0';
                  if (n > widget.balanceDue) {
                    return 'Exceeds balance ${widget.balanceDue}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tdsAmount,
                decoration: const InputDecoration(
                  labelText: 'TDS withheld (optional)',
                  isDense: true,
                  prefixText: '₹ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _mode,
                decoration: const InputDecoration(
                    labelText: 'Mode *', isDense: true),
                items: kPaymentModes
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _mode = v ?? kPaymentModes.first),
              ),
              const SizedBox(height: 12),
              AccountPicker(
                accountType: 'asset',
                label: 'Bank / Cash account *',
                selectedId: _bankAccount?.id,
                onChanged: (a) => setState(() => _bankAccount = a),
                validator: (id) => id == null ? 'Required' : null,
              ),
              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Reference (cheque #, UTR, etc.)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
