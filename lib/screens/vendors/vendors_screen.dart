import 'package:community_admin/main.dart' show showRootSnackBar;
import 'package:community_admin/models/vendor.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Vendor master list. Search + tap-to-detail + FAB to add.
class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  final _searchCtl = TextEditingController();
  List<Vendor> _vendors = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final svc = ref.read(vendorServiceProvider);
      final res = await svc.list(
        search: _searchCtl.text.trim().isNotEmpty
            ? _searchCtl.text.trim()
            : null,
      );
      if (!mounted) return;
      setState(() {
        _vendors = res.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/vendors/new');
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Vendor'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: 'Search vendors...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          _load();
                        },
                      )
                    : null,
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _errorView()
                    : _vendors.isEmpty
                        ? Center(
                            child: Text(
                              'No vendors yet',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: _vendors.length,
                              itemBuilder: (context, index) {
                                final v = _vendors[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        v.name.isEmpty
                                            ? 'V'
                                            : v.name
                                                .substring(0, 1)
                                                .toUpperCase(),
                                      ),
                                    ),
                                    title: Text(
                                      v.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (v.gstin != null && v.gstin!.isNotEmpty)
                                          'GST: ${v.gstin}',
                                        if (v.phone != null && v.phone!.isNotEmpty)
                                          v.phone!,
                                      ].join(' · '),
                                    ),
                                    trailing: !v.isActive
                                        ? const Chip(
                                            label: Text('Inactive'),
                                            visualDensity: VisualDensity.compact,
                                          )
                                        : const Icon(Icons.chevron_right),
                                    onTap: () async {
                                      final changed = await context
                                          .push<bool>('/vendors/${v.id}');
                                      if (changed == true) _load();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
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
            ElevatedButton(
              onPressed: () {
                _load();
                showRootSnackBar('Retrying…');
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
