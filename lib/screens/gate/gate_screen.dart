import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

class GateScreen extends ConsumerStatefulWidget {
  const GateScreen({super.key});

  @override
  ConsumerState<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends ConsumerState<GateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Gate Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Visitors'),
            Tab(text: 'Parcels'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VisitorsTab(),
          _ParcelsTab(),
        ],
      ),
    );
  }
}

// --- Visitors Tab ---
class _VisitorsTab extends ConsumerStatefulWidget {
  const _VisitorsTab();

  @override
  ConsumerState<_VisitorsTab> createState() => _VisitorsTabState();
}

class _VisitorsTabState extends ConsumerState<_VisitorsTab> {
  List<dynamic> _visitors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(gateServiceProvider).getVisitors();
      if (mounted) {
        setState(() {
          _visitors = (data['items'] as List<dynamic>?) ??
              (data['visitors'] as List<dynamic>?) ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIn(String id) async {
    try {
      await ref.read(gateServiceProvider).checkInVisitor(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to check in')),
        );
      }
    }
  }

  Future<void> _checkOut(String id) async {
    try {
      await ref.read(gateServiceProvider).checkOutVisitor(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to check out')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'checked_in':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'rejected':
      case 'checked_out':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_visitors.isEmpty) {
      return Center(
        child: Text('No visitors', style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _visitors.length,
        itemBuilder: (context, index) {
          final visitor = _visitors[index] as Map<String, dynamic>;
          final name = visitor['visitor_name'] ?? visitor['visitorName'] ?? '';
          final status = (visitor['status'] as String?) ?? 'pending';
          final unitNumber =
              visitor['unit_number'] ?? visitor['unitNumber'] ?? '';
          final purpose = visitor['purpose'] ?? '';
          final id = visitor['id'] as String;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unit $unitNumber${purpose.toString().isNotEmpty ? ' | $purpose' : ''}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (status == 'approved' || status == 'pending') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'approved')
                          TextButton.icon(
                            onPressed: () => _checkIn(id),
                            icon: const Icon(Icons.login, size: 18),
                            label: const Text('Check In'),
                          ),
                        if (status == 'approved')
                          const SizedBox(width: 8),
                        if (status == 'pending' || status == 'approved')
                          TextButton.icon(
                            onPressed: () => _checkOut(id),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Check Out'),
                          ),
                      ],
                    ),
                  ],
                  if (status == 'checked_in') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _checkOut(id),
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Check Out'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Parcels Tab ---
class _ParcelsTab extends ConsumerStatefulWidget {
  const _ParcelsTab();

  @override
  ConsumerState<_ParcelsTab> createState() => _ParcelsTabState();
}

class _ParcelsTabState extends ConsumerState<_ParcelsTab> {
  List<dynamic> _parcels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(gateServiceProvider).getParcels();
      if (mounted) {
        setState(() {
          _parcels = (data['items'] as List<dynamic>?) ??
              (data['parcels'] as List<dynamic>?) ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _collect(String id) async {
    try {
      await ref.read(gateServiceProvider).collectParcel(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark as collected')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_parcels.isEmpty) {
      return Center(
        child: Text('No parcels', style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _parcels.length,
        itemBuilder: (context, index) {
          final parcel = _parcels[index] as Map<String, dynamic>;
          final courier = parcel['courier'] ?? parcel['courier_name'] ?? '';
          final unitNumber =
              parcel['unit_number'] ?? parcel['unitNumber'] ?? '';
          final isCollected = parcel['is_collected'] ??
              parcel['isCollected'] ??
              parcel['status'] == 'collected';
          final id = parcel['id'] as String;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isCollected == true
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Icon(
                  Icons.inventory_2,
                  color: isCollected == true
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
              title: Text(
                'Unit $unitNumber',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(courier.toString()),
              trailing: isCollected == true
                  ? Chip(
                      label: const Text('Collected'),
                      backgroundColor: Colors.green.shade50,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    )
                  : TextButton(
                      onPressed: () => _collect(id),
                      child: const Text('Collect'),
                    ),
            ),
          );
        },
      ),
    );
  }
}
