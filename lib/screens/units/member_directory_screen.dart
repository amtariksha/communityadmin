import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

class MemberDirectoryScreen extends ConsumerStatefulWidget {
  const MemberDirectoryScreen({super.key});

  @override
  ConsumerState<MemberDirectoryScreen> createState() =>
      _MemberDirectoryScreenState();
}

class _MemberDirectoryScreenState
    extends ConsumerState<MemberDirectoryScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();
  String? _selectedType;

  static const _memberTypes = ['owner', 'tenant', 'owner_family', 'tenant_family'];
  static const _typeLabels = {
    'owner': 'Owner',
    'tenant': 'Tenant',
    'owner_family': 'Owner Family',
    'tenant_family': 'Tenant Family',
  };

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final unitService = ref.read(unitServiceProvider);
      final data = await unitService.getMemberDirectory(
        search: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
        memberType: _selectedType,
      );
      if (mounted) {
        setState(() {
          _members = (data['items'] as List<dynamic>?) ??
              (data['members'] as List<dynamic>?) ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load directory';
          _isLoading = false;
        });
      }
    }
  }

  Color _badgeColor(String memberType) {
    switch (memberType) {
      case 'owner':
        return AppTheme.primaryColor;
      case 'tenant':
        return Colors.teal;
      case 'owner_family':
        return Colors.blue.shade400;
      case 'tenant_family':
        return Colors.cyan.shade600;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Member Directory')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadMembers();
                        },
                      )
                    : null,
                isDense: true,
              ),
              onSubmitted: (_) => _loadMembers(),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedType == null,
                    onSelected: (_) {
                      setState(() => _selectedType = null);
                      _loadMembers();
                    },
                    selectedColor:
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                  ),
                  const SizedBox(width: 8),
                  ..._memberTypes.map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_typeLabels[type] ?? type),
                        selected: _selectedType == type,
                        onSelected: (_) {
                          setState(() => _selectedType =
                              _selectedType == type ? null : type);
                          _loadMembers();
                        },
                        selectedColor:
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Member list
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
                              onPressed: _loadMembers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _members.isEmpty
                        ? Center(
                            child: Text(
                              'No members found',
                              style:
                                  TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadMembers,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _members.length,
                              itemBuilder: (context, index) {
                                final member = _members[index]
                                    as Map<String, dynamic>;
                                final name =
                                    member['name'] as String? ?? '';
                                final phone =
                                    member['phone'] as String? ?? '';
                                final unitNumber =
                                    member['unit_number'] ??
                                        member['unitNumber'] ??
                                        '';
                                final memberType =
                                    member['member_type'] ??
                                        member['memberType'] ??
                                        '';
                                final typeLabel =
                                    _typeLabels[memberType] ??
                                        memberType.toString();

                                return Card(
                                  margin:
                                      const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Colors.grey.shade200,
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${phone.isNotEmpty ? phone : 'No phone'}${unitNumber.toString().isNotEmpty ? ' | Unit $unitNumber' : ''}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _badgeColor(
                                                memberType.toString())
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        typeLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _badgeColor(
                                              memberType.toString()),
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
