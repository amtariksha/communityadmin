import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/models/ocr_result.dart';
import 'package:community_admin/providers/service_providers.dart';

final _currencyFormat =
    NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

/// Pull structured data out of a vendor invoice — GSTIN / PAN / totals /
/// line items — using Gemini OCR. Admin can copy fields into the web
/// purchases form (full purchase CRUD stays web-only).
class InvoiceScanScreen extends ConsumerStatefulWidget {
  const InvoiceScanScreen({super.key});

  @override
  ConsumerState<InvoiceScanScreen> createState() =>
      _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends ConsumerState<InvoiceScanScreen> {
  final _picker = ImagePicker();
  File? _image;
  InvoiceOcrResult? _result;
  bool _scanning = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2400,
      );
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _result = null;
        _error = null;
      });
      await _scan();
    } catch (e) {
      setState(() => _error = 'Could not pick image: $e');
    }
  }

  Future<void> _scan() async {
    if (_image == null) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final bytes = await _image!.readAsBytes();
      final mime = _image!.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final result = await ref
          .read(ocrServiceProvider)
          .extractInvoice(bytes, mimeType: mime);
      if (!mounted) return;
      setState(() {
        _result = result;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _copy(String? value) async {
    if (value == null || value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied: $value')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Invoice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 220, fit: BoxFit.cover),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Snap the vendor invoice',
                          style:
                              TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _scanning ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _scanning ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_scanning) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Extracting invoice fields with AI\u2026'),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (_result != null) _ResultCard(result: _result!, onCopy: _copy),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final InvoiceOcrResult result;
  final Future<void> Function(String?) onCopy;
  const _ResultCard({required this.result, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Vendor',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    Text(
                      '${(result.confidence * 100).toStringAsFixed(0)}% confidence',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _Kv('Name', result.vendorName, onCopy: onCopy),
                _Kv('GSTIN', result.vendorGstin, onCopy: onCopy),
                _Kv('PAN', result.vendorPan, onCopy: onCopy),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Invoice',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                _Kv('Number', result.invoiceNumber, onCopy: onCopy),
                _Kv('Date', result.invoiceDate, onCopy: onCopy),
                _Kv('Due', result.dueDate, onCopy: onCopy),
                if (result.subtotal != null)
                  _Kv('Subtotal', _currencyFormat.format(result.subtotal),
                      onCopy: onCopy),
                if (result.gstAmount != null)
                  _Kv('GST', _currencyFormat.format(result.gstAmount),
                      onCopy: onCopy),
                if (result.totalAmount != null)
                  _Kv('Total', _currencyFormat.format(result.totalAmount),
                      onCopy: onCopy, emphasize: true),
              ],
            ),
          ),
        ),
        if (result.lineItems.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Line items',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  for (final item in result.lineItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item.description,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text(
                            _currencyFormat.format(item.amount),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (result.bankDetails != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bank',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  _Kv('Bank', result.bankDetails!.bankName,
                      onCopy: onCopy),
                  _Kv('Account', result.bankDetails!.accountNumber,
                      onCopy: onCopy),
                  _Kv('IFSC', result.bankDetails!.ifsc, onCopy: onCopy),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  final String label;
  final String? value;
  final Future<void> Function(String?) onCopy;
  final bool emphasize;
  const _Kv(this.label, this.value,
      {required this.onCopy, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value!,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    emphasize ? FontWeight.w700 : FontWeight.normal,
                color: emphasize ? AppTheme.primaryColor : null,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => onCopy(value),
          ),
        ],
      ),
    );
  }
}
