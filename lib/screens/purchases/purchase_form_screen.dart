import 'dart:io';
import 'dart:typed_data';

import 'package:community_admin/main.dart' show showRootSnackBar;
import 'package:community_admin/models/ledger_account.dart';
import 'package:community_admin/models/ocr_result.dart';
import 'package:community_admin/models/vendor.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/widgets/account_picker.dart';
import 'package:community_admin/widgets/vendor_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Create a vendor bill. Supports optional OCR prefill — when
/// `fromScan` is true the screen opens the camera/gallery first and
/// pre-populates fields from the parsed invoice. Manual entry is the
/// default.
class PurchaseFormScreen extends ConsumerStatefulWidget {
  final bool fromScan;
  const PurchaseFormScreen({super.key, this.fromScan = false});

  @override
  ConsumerState<PurchaseFormScreen> createState() =>
      _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billNumber = TextEditingController();
  final _totalAmount = TextEditingController();
  final _gstAmount = TextEditingController();
  final _tdsAmount = TextEditingController();
  final _narration = TextEditingController();

  Vendor? _vendor;
  LedgerAccount? _expenseAccount;
  LedgerAccount? _payableAccount;
  DateTime _billDate = DateTime.now();
  DateTime? _dueDate;

  bool _loading = false;
  bool _scanning = false;
  String? _error;

  // OCR confidence to surface to the user when fields were prefilled.
  double? _ocrConfidence;
  String? _ocrVendorName; // when vendor not in master, show hint

  @override
  void initState() {
    super.initState();
    if (widget.fromScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runScan());
    }
  }

  @override
  void dispose() {
    _billNumber.dispose();
    _totalAmount.dispose();
    _gstAmount.dispose();
    _tdsAmount.dispose();
    _narration.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // OCR
  // ---------------------------------------------------------------------------

  Future<void> _runScan() async {
    setState(() => _scanning = true);
    try {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) {
        if (mounted) setState(() => _scanning = false);
        return;
      }
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (picked == null) {
        if (mounted) setState(() => _scanning = false);
        return;
      }
      final bytes = await File(picked.path).readAsBytes();
      await _extractAndPrefill(bytes, picked.path);
    } catch (e) {
      if (mounted) {
        showRootSnackBar('Scan failed: $e');
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _extractAndPrefill(Uint8List bytes, String path) async {
    try {
      final mime = path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final result = await ref
          .read(ocrServiceProvider)
          .extractInvoice(bytes, mimeType: mime);
      _applyOcr(result);
    } catch (e) {
      if (mounted) {
        showRootSnackBar('OCR failed: $e');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _applyOcr(InvoiceOcrResult r) {
    if (r.invoiceNumber != null) _billNumber.text = r.invoiceNumber!;
    if (r.totalAmount != null) {
      _totalAmount.text = r.totalAmount!.toStringAsFixed(2);
    }
    if (r.gstAmount != null) {
      _gstAmount.text = r.gstAmount!.toStringAsFixed(2);
    }
    if (r.invoiceDate != null) {
      final parsed = DateTime.tryParse(r.invoiceDate!);
      if (parsed != null) _billDate = parsed;
    }
    if (r.dueDate != null) {
      _dueDate = DateTime.tryParse(r.dueDate!);
    }
    if (r.vendorName != null && r.vendorName!.isNotEmpty) {
      _ocrVendorName = r.vendorName;
    }
    _ocrConfidence = r.confidence;
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendor == null) {
      setState(() => _error = 'Please pick a vendor');
      return;
    }
    if (_expenseAccount == null) {
      setState(() => _error = 'Please pick an expense account');
      return;
    }
    if (_payableAccount == null) {
      setState(() => _error = 'Please pick a payable account');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final body = <String, dynamic>{
        'vendor_id': _vendor!.id,
        'bill_date': fmt.format(_billDate),
        'total_amount': num.tryParse(_totalAmount.text.trim()) ?? 0,
        'expense_account_id': _expenseAccount!.id,
        'payable_account_id': _payableAccount!.id,
        if (_billNumber.text.trim().isNotEmpty)
          'bill_number': _billNumber.text.trim(),
        if (_dueDate != null) 'due_date': fmt.format(_dueDate!),
        if (_gstAmount.text.trim().isNotEmpty)
          'gst_amount': num.tryParse(_gstAmount.text.trim()) ?? 0,
        if (_tdsAmount.text.trim().isNotEmpty)
          'tds_amount': num.tryParse(_tdsAmount.text.trim()) ?? 0,
        if (_narration.text.trim().isNotEmpty)
          'narration': _narration.text.trim(),
      };
      await ref.read(purchaseServiceProvider).createBill(body);
      if (!mounted) return;
      showRootSnackBar('Bill created');
      context.pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate({required bool isDue}) async {
    final initial = isDue ? (_dueDate ?? _billDate) : _billDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isDue) {
          _dueDate = picked;
        } else {
          _billDate = picked;
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dfmt = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill'),
        actions: [
          IconButton(
            tooltip: 'Scan invoice',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: _scanning ? null : _runScan,
          ),
        ],
      ),
      body: _scanning
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning invoice…'),
                ],
              ),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (_ocrConfidence != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Prefilled from scan (confidence ${(_ocrConfidence! * 100).toStringAsFixed(0)}%). Review every field before saving.',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    if (_ocrVendorName != null && _vendor == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'OCR vendor: "$_ocrVendorName" — pick a matching master record below.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    VendorPicker(
                      selectedId: _vendor?.id,
                      onChanged: (v) => setState(() => _vendor = v),
                      validator: (id) => id == null ? 'Required' : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Bill date *',
                            value: dfmt.format(_billDate),
                            onTap: () => _pickDate(isDue: false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Due date',
                            value: _dueDate == null
                                ? '—'
                                : dfmt.format(_dueDate!),
                            onTap: () => _pickDate(isDue: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _billNumber,
                      decoration: const InputDecoration(
                        labelText: 'Bill number',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _totalAmount,
                      decoration: const InputDecoration(
                        labelText: 'Total amount *',
                        isDense: true,
                        prefixText: '₹ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = num.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _gstAmount,
                            decoration: const InputDecoration(
                              labelText: 'GST',
                              isDense: true,
                              prefixText: '₹ ',
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tdsAmount,
                            decoration: const InputDecoration(
                              labelText: 'TDS',
                              isDense: true,
                              prefixText: '₹ ',
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AccountPicker(
                      accountType: 'expense',
                      label: 'Expense account *',
                      selectedId: _expenseAccount?.id,
                      onChanged: (a) =>
                          setState(() => _expenseAccount = a),
                      validator: (id) => id == null ? 'Required' : null,
                    ),
                    AccountPicker(
                      accountType: 'liability',
                      label: 'Payable account *',
                      selectedId: _payableAccount?.id,
                      onChanged: (a) =>
                          setState(() => _payableAccount = a),
                      validator: (id) => id == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _narration,
                      decoration: const InputDecoration(
                        labelText: 'Narration',
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create bill'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateField(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
        ),
        child: Text(value),
      ),
    );
  }
}
