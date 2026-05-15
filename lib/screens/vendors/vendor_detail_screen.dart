import 'package:community_admin/main.dart' show showRootSnackBar;
import 'package:community_admin/models/vendor.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VendorDetailScreen extends ConsumerStatefulWidget {
  final String vendorId;
  const VendorDetailScreen({super.key, required this.vendorId});

  @override
  ConsumerState<VendorDetailScreen> createState() =>
      _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen> {
  Vendor? _vendor;
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
      final v = await ref.read(vendorServiceProvider).get(widget.vendorId);
      if (!mounted) return;
      setState(() {
        _vendor = v;
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

  Future<void> _deactivate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate vendor?'),
        content: const Text(
            'The vendor will no longer appear in new bill flows. Existing bills are preserved. You can reactivate later from the admin web.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(vendorServiceProvider).deactivate(widget.vendorId);
      if (!mounted) return;
      showRootSnackBar('Vendor deactivated');
      _changed = true;
      context.pop(true);
    } catch (e) {
      showRootSnackBar('Could not deactivate: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _changed) {
          // already popped with the result expected
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendor'),
          actions: [
            if (_vendor != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final updated = await context
                      .push<bool>('/vendors/${widget.vendorId}/edit');
                  if (updated == true) {
                    _changed = true;
                    _load();
                  }
                },
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : _vendor == null
                    ? const Center(child: Text('Not found'))
                    : _detailBody(_vendor!),
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

  Widget _detailBody(Vendor v) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (!v.isActive)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Chip(
                      label: Text('Inactive'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const SizedBox(height: 12),
                _kv('Contact', v.contactPerson),
                _kv('Phone', v.phone),
                _kv('Email', v.email),
                _kv('Address', v.address),
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
                const Text('Tax IDs',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _kv('GSTIN', v.gstin),
                _kv('PAN', v.pan),
                _kv('TDS Section', v.tdsSection),
                _kv('TDS Rate',
                    v.tdsRate == null ? null : '${v.tdsRate}%'),
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
                const Text('Bank',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _kv('Bank', v.bankName),
                _kv('Branch', v.bankBranch),
                _kv('Account', v.bankAccountNumber),
                _kv('IFSC', v.bankIfsc),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (v.isActive)
          OutlinedButton.icon(
            onPressed: _deactivate,
            icon: const Icon(Icons.block, color: Colors.red),
            label: const Text('Deactivate vendor',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _kv(String label, String? value) {
    final display = value == null || value.isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
}
