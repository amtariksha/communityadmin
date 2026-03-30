import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:community_admin/providers/service_providers.dart';

class UnitsScreen extends ConsumerStatefulWidget {
  const UnitsScreen({super.key});

  @override
  ConsumerState<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends ConsumerState<UnitsScreen> {
  List<dynamic> _units = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();
  String? _selectedBlock;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final unitService = ref.read(unitServiceProvider);
      final data = await unitService.getUnits(
        search: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
        block: _selectedBlock,
      );
      if (mounted) {
        setState(() {
          _units = (data['items'] as List<dynamic>?) ??
              (data['units'] as List<dynamic>?) ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load units';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Units')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search units...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadUnits();
                              },
                            )
                          : null,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadUnits(),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (value) {
                    setState(() => _selectedBlock = value);
                    _loadUnits();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('All Blocks')),
                    const PopupMenuItem(value: 'A', child: Text('Block A')),
                    const PopupMenuItem(value: 'B', child: Text('Block B')),
                    const PopupMenuItem(value: 'C', child: Text('Block C')),
                  ],
                ),
              ],
            ),
          ),

          // Unit list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadUnits,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _units.isEmpty
                        ? Center(
                            child: Text(
                              'No units found',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadUnits,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _units.length,
                              itemBuilder: (context, index) {
                                final unit =
                                    _units[index] as Map<String, dynamic>;
                                final unitNumber = unit['unit_number'] ??
                                    unit['unitNumber'] ??
                                    '';
                                final block = unit['block'] ?? '';
                                final floor = unit['floor'] ?? '';
                                final area = unit['area'] ?? '';
                                final isOccupied =
                                    unit['is_occupied'] ?? unit['isOccupied'] ?? false;
                                final ownerName =
                                    unit['owner_name'] ?? unit['ownerName'] ?? '';
                                final tenantName =
                                    unit['tenant_name'] ?? unit['tenantName'] ?? '';
                                final unitId = unit['id'] as String;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    onTap: () => context.push('/units/$unitId'),
                                    title: Text(
                                      'Unit $unitNumber',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Block $block | Floor $floor${area.toString().isNotEmpty ? ' | $area sq ft' : ''}',
                                        ),
                                        if (ownerName.toString().isNotEmpty ||
                                            tenantName.toString().isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              [
                                                if (ownerName
                                                    .toString()
                                                    .isNotEmpty)
                                                  'Owner: $ownerName',
                                                if (tenantName
                                                    .toString()
                                                    .isNotEmpty)
                                                  'Tenant: $tenantName',
                                              ].join(' | '),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOccupied == true
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isOccupied == true
                                            ? 'Occupied'
                                            : 'Vacant',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isOccupied == true
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
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
}
