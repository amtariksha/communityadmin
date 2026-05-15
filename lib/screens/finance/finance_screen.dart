import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/main.dart' show showRootSnackBar;
import 'package:community_admin/providers/service_providers.dart';
import 'package:intl/intl.dart';

/// Parse a backend-supplied money/quantity value defensively.
///
/// The accounting backend serializes monetary columns as strings
/// (`"2520.00"`) to preserve decimal precision, but `NumberFormat.format`
/// requires a `num`. Without this helper every row build crashed
/// with `NoSuchMethodError: 'String' has no instance getter 'isNegative'`
/// and the entire tab rendered blank.
num _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Invoices'),
            Tab(text: 'Receipts'),
            Tab(text: 'Defaulters'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _InvoicesTab(),
          _ReceiptsTab(),
          _DefaultersTab(),
        ],
      ),
    );
  }
}

// --- Invoices Tab ---
class _InvoicesTab extends ConsumerStatefulWidget {
  const _InvoicesTab();

  @override
  ConsumerState<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends ConsumerState<_InvoicesTab> {
  List<dynamic> _invoices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ref.read(invoiceServiceProvider).getInvoices();
      if (mounted) {
        setState(() {
          _invoices = (data['items'] as List<dynamic>?) ??
              (data['invoices'] as List<dynamic>?) ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'posted':
      case 'paid':
        return AppTheme.successColor;
      case 'draft':
        return Colors.grey;
      case 'overdue':
        return AppTheme.errorColor;
      case 'partial':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _LoadErrorView(message: _error!, onRetry: _load);
    }

    return Stack(
      children: [
        _invoices.isEmpty
            ? Center(
                child: Text('No invoices found',
                    style: TextStyle(color: Colors.grey.shade500)),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final inv = _invoices[index] as Map<String, dynamic>;
                    final status = (inv['status'] as String?) ?? 'draft';
                    // Backend returns total_amount as a String (e.g.
                    // "11000.00"); NumberFormat.format requires a num.
                    // Parse defensively to avoid the row-build crash
                    // that turned a real invoice list into a blank tab.
                    final amount = _toNum(inv['total_amount'] ?? inv['totalAmount']);
                    final unitNumber =
                        inv['unit_number'] ?? inv['unitNumber'] ?? '';
                    final invoiceNumber =
                        inv['invoice_number'] ?? inv['invoiceNumber'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '#$invoiceNumber',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Unit $unitNumber'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\u20B9${NumberFormat('#,##0').format(amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => showRootSnackBar('Invoice generation coming soon'),
            icon: const Icon(Icons.add),
            label: const Text('Generate'),
          ),
        ),
      ],
    );
  }
}

// --- Receipts Tab ---
class _ReceiptsTab extends ConsumerStatefulWidget {
  const _ReceiptsTab();

  @override
  ConsumerState<_ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends ConsumerState<_ReceiptsTab> {
  List<dynamic> _receipts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ref.read(receiptServiceProvider).getReceipts();
      if (mounted) {
        setState(() {
          _receipts = (data['items'] as List<dynamic>?) ??
              (data['receipts'] as List<dynamic>?) ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _LoadErrorView(message: _error!, onRetry: _load);
    }

    return Stack(
      children: [
        _receipts.isEmpty
            ? Center(
                child: Text('No receipts found',
                    style: TextStyle(color: Colors.grey.shade500)),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _receipts.length,
                  itemBuilder: (context, index) {
                    final receipt = _receipts[index] as Map<String, dynamic>;
                    final amount =
                        _toNum(receipt['amount'] ?? receipt['total_amount']);
                    final mode = receipt['mode'] ?? '';
                    final unitNumber =
                        receipt['unit_number'] ?? receipt['unitNumber'] ?? '';
                    final receiptNumber =
                        receipt['receipt_number'] ?? receipt['receiptNumber'] ?? '';
                    final date = receipt['receipt_date'] ??
                        receipt['receiptDate'] ??
                        receipt['created_at'] ??
                        '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '#$receiptNumber',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Unit $unitNumber | $mode'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\u20B9${NumberFormat('#,##0').format(amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (date.toString().isNotEmpty)
                              Text(
                                date.toString().substring(0, 10),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => showRootSnackBar('Receipt creation coming soon'),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ),
      ],
    );
  }
}

// --- Defaulters Tab ---
class _DefaultersTab extends ConsumerStatefulWidget {
  const _DefaultersTab();

  @override
  ConsumerState<_DefaultersTab> createState() => _DefaultersTabState();
}

class _DefaultersTabState extends ConsumerState<_DefaultersTab> {
  List<dynamic> _defaulters = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(invoiceServiceProvider).getInvoices(status: 'overdue');
      if (mounted) {
        setState(() {
          _defaulters = (data['items'] as List<dynamic>?) ??
              (data['invoices'] as List<dynamic>?) ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _LoadErrorView(message: _error!, onRetry: _load);
    }

    if (_defaulters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text(
              'No defaulters',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _defaulters.length,
        itemBuilder: (context, index) {
          final inv = _defaulters[index] as Map<String, dynamic>;
          final amount = _toNum(inv['total_amount'] ?? inv['totalAmount']);
          final unitNumber = inv['unit_number'] ?? inv['unitNumber'] ?? '';
          final dueDate = inv['due_date'] ?? inv['dueDate'] ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                child: const Icon(Icons.warning, color: AppTheme.errorColor),
              ),
              title: Text(
                'Unit $unitNumber',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: dueDate.toString().isNotEmpty
                  ? Text('Due: ${dueDate.toString().substring(0, 10)}')
                  : null,
              trailing: Text(
                '\u20B9${NumberFormat('#,##0').format(amount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Could not load',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
