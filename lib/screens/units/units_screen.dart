import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _showMembersSheet(Map<String, dynamic> unit) async {
    final unitService = ref.read(unitServiceProvider);
    final unitId = unit['id'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<dynamic>>(
              future: unitService.getUnitMembers(unitId),
              builder: (context, snapshot) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unit ${unit['unit_number'] ?? unit['unitNumber'] ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Block ${unit['block'] ?? ''} | Floor ${unit['floor'] ?? ''}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Members',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (snapshot.hasError)
                        const Text('Failed to load members')
                      else if (snapshot.data?.isEmpty ?? true)
                        Text(
                          'No members found',
                          style: TextStyle(color: Colors.grey.shade500),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              final member =
                                  snapshot.data![index] as Map<String, dynamic>;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  child: Text(
                                    (member['name'] as String? ?? '?')[0]
                                        .toUpperCase(),
                                  ),
                                ),
                                title: Text(member['name'] as String? ?? ''),
                                subtitle: Text(
                                  member['member_type'] as String? ??
                                      member['memberType'] as String? ??
                                      '',
                                ),
                                trailing: Text(
                                  member['phone'] as String? ?? '',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
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

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    onTap: () => _showMembersSheet(unit),
                                    title: Text(
                                      'Unit $unitNumber',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      'Block $block | Floor $floor${area != '' ? ' | $area sq ft' : ''}',
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
