import 'package:community_admin/config/theme.dart';
import 'package:community_admin/models/vendor_bill.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Vendor bill list with status tabs. FAB opens a sheet offering
/// manual create vs scan-invoice-prefill.
class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab → backend status filter (null = all)
  static const _tabs = [
    ('All', null),
    ('Draft', 'draft'),
    ('Unpaid', 'received'),
    ('Paid', 'paid'),
    ('Overdue', 'overdue'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreateMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner,
                  color: AppTheme.primaryColor),
              title: const Text('Scan invoice'),
              subtitle: const Text(
                  'Capture or pick a bill image — fields auto-fill from OCR'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/purchases/new?from=scan');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add,
                  color: AppTheme.primaryColor),
              title: const Text('Manual entry'),
              subtitle: const Text('Enter bill details by hand'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/purchases/new');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Bills'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateMenu,
        icon: const Icon(Icons.add),
        label: const Text('New Bill'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((t) => _BillsList(statusFilter: t.$2))
            .toList(),
      ),
    );
  }
}

class _BillsList extends ConsumerStatefulWidget {
  final String? statusFilter;
  const _BillsList({required this.statusFilter});

  @override
  ConsumerState<_BillsList> createState() => _BillsListState();
}

class _BillsListState extends ConsumerState<_BillsList>
    with AutomaticKeepAliveClientMixin {
  List<VendorBill> _bills = const [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final res = await ref
          .read(purchaseServiceProvider)
          .listBills(status: widget.statusFilter, limit: 50);
      if (!mounted) return;
      setState(() {
        _bills = res.items;
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
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
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
    }
    if (_bills.isEmpty) {
      return Center(
        child: Text('No bills', style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final b = _bills[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('#${b.billNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                [
                  b.vendorName ?? 'Vendor',
                  if (b.billDate.isNotEmpty)
                    b.billDate.length >= 10
                        ? b.billDate.substring(0, 10)
                        : b.billDate,
                ].join(' · '),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${NumberFormat('#,##0').format(b.totalAmount)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  _StatusBadge(status: b.status),
                ],
              ),
              onTap: () async {
                final changed = await context.push<bool>('/purchases/${b.id}');
                if (changed == true) _load();
              },
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
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
