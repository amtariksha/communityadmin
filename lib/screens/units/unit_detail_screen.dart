import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

class UnitDetailScreen extends ConsumerStatefulWidget {
  final String unitId;

  const UnitDetailScreen({super.key, required this.unitId});

  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
  Map<String, dynamic>? _unit;
  List<dynamic> _members = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final unitService = ref.read(unitServiceProvider);
      final results = await Future.wait([
        unitService.getUnitDetail(widget.unitId),
        unitService.getMembers(widget.unitId),
      ]);
      if (mounted) {
        setState(() {
          _unit = results[0] as Map<String, dynamic>;
          _members = results[1] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load unit details';
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _ownerFamily => _members
      .where((m) =>
          (m['member_type'] ?? m['memberType']) == 'owner_family')
      .toList();

  List<dynamic> get _tenantFamily => _members
      .where((m) =>
          (m['member_type'] ?? m['memberType']) == 'tenant_family')
      .toList();

  Map<String, dynamic>? get _owner {
    final owners = _members.where((m) =>
        (m['member_type'] ?? m['memberType']) == 'owner');
    return owners.isNotEmpty
        ? owners.first as Map<String, dynamic>
        : null;
  }

  Map<String, dynamic>? get _tenant {
    final tenants = _members.where((m) =>
        (m['member_type'] ?? m['memberType']) == 'tenant');
    return tenants.isNotEmpty
        ? tenants.first as Map<String, dynamic>
        : null;
  }

  Future<void> _showAddMemberDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedType = 'owner_family';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Member'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration:
                          const InputDecoration(labelText: 'Member Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'owner_family',
                          child: Text('Owner Family'),
                        ),
                        DropdownMenuItem(
                          value: 'tenant',
                          child: Text('Tenant'),
                        ),
                        DropdownMenuItem(
                          value: 'tenant_family',
                          child: Text('Tenant Family'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedType = value!);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        await ref.read(unitServiceProvider).addMember(
              widget.unitId,
              name: nameCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              memberType: selectedType,
            );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member added')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add member')),
          );
        }
      }
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _showEditMemberDialog(Map<String, dynamic> member) async {
    final nameCtrl =
        TextEditingController(text: member['name'] as String? ?? '');
    final phoneCtrl =
        TextEditingController(text: member['phone'] as String? ?? '');
    final emailCtrl =
        TextEditingController(text: member['email'] as String? ?? '');
    final memberId = member['id'] as String;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        await ref.read(unitServiceProvider).updateMember(
              widget.unitId,
              memberId,
              name: nameCtrl.text.trim().isNotEmpty
                  ? nameCtrl.text.trim()
                  : null,
              phone: phoneCtrl.text.trim().isNotEmpty
                  ? phoneCtrl.text.trim()
                  : null,
              email: emailCtrl.text.trim().isNotEmpty
                  ? emailCtrl.text.trim()
                  : null,
            );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update member')),
          );
        }
      }
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
  }

  Future<void> _confirmRemoveMember(Map<String, dynamic> member) async {
    final memberId = member['id'] as String;
    final memberName = member['name'] as String? ?? 'this member';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $memberName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(unitServiceProvider).removeMember(
              widget.unitId,
              memberId,
            );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member removed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove member')),
          );
        }
      }
    }
  }

  Future<void> _showTransferOwnershipDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Transfer Ownership'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the details of the new owner. The current owner and their family members will be removed.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone *'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Transfer'),
            ),
          ],
        );
      },
    );

    if (result == true &&
        nameCtrl.text.trim().isNotEmpty &&
        phoneCtrl.text.trim().isNotEmpty) {
      try {
        await ref.read(unitServiceProvider).transferOwnership(
              widget.unitId,
              name: nameCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              email: emailCtrl.text.trim().isNotEmpty
                  ? emailCtrl.text.trim()
                  : null,
            );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ownership transferred')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to transfer ownership')),
          );
        }
      }
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
  }

  Future<void> _confirmDisconnectTenant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Tenant'),
        content: const Text(
          'Are you sure you want to disconnect the tenant? '
          'The tenant and their family members will be removed from this unit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(unitServiceProvider)
            .disconnectTenant(widget.unitId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tenant disconnected')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to disconnect tenant')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _unit != null
              ? 'Unit ${_unit!['unit_number'] ?? _unit!['unitNumber'] ?? ''}'
              : 'Unit Detail',
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'transfer') _showTransferOwnershipDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'transfer',
                child: ListTile(
                  leading: Icon(Icons.swap_horiz),
                  title: Text('Transfer Ownership'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemberDialog,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildUnitInfoCard(),
                      const SizedBox(height: 16),
                      _buildOwnerCard(),
                      const SizedBox(height: 12),
                      if (_ownerFamily.isNotEmpty) ...[
                        _buildFamilySection(
                          'Owner Family',
                          _ownerFamily,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildTenantCard(),
                      const SizedBox(height: 12),
                      if (_tenantFamily.isNotEmpty) ...[
                        _buildFamilySection(
                          'Tenant Family',
                          _tenantFamily,
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
    );
  }

  Widget _buildUnitInfoCard() {
    final unit = _unit!;
    final unitNumber =
        unit['unit_number'] ?? unit['unitNumber'] ?? '';
    final block = unit['block'] ?? '';
    final floor = unit['floor'] ?? '';
    final area = unit['area'] ?? '';
    final unitType = unit['unit_type'] ?? unit['unitType'] ?? '';
    final isOccupied =
        unit['is_occupied'] ?? unit['isOccupied'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.apartment,
                    color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Unit $unitNumber',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
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
                    isOccupied == true ? 'Occupied' : 'Vacant',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isOccupied == true
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _infoChip(Icons.domain, 'Block $block'),
                _infoChip(Icons.layers, 'Floor $floor'),
                if (area.toString().isNotEmpty)
                  _infoChip(Icons.square_foot, '$area sq ft'),
                if (unitType.toString().isNotEmpty)
                  _infoChip(Icons.category, unitType.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildOwnerCard() {
    final owner = _owner;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OWNER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (owner != null)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditMemberDialog(owner),
                    tooltip: 'Edit',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (owner != null) ...[
              Text(
                owner['name'] as String? ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              if ((owner['phone'] as String?)?.isNotEmpty == true)
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      owner['phone'] as String,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              if ((owner['email'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      owner['email'] as String,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ] else
              Text(
                'No owner assigned',
                style: TextStyle(color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantCard() {
    final tenant = _tenant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TENANT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                if (tenant != null) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditMemberDialog(tenant),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: Icon(Icons.link_off,
                        size: 20, color: AppTheme.errorColor),
                    onPressed: _confirmDisconnectTenant,
                    tooltip: 'Disconnect',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (tenant != null) ...[
              Text(
                tenant['name'] as String? ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              if ((tenant['phone'] as String?)?.isNotEmpty == true)
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      tenant['phone'] as String,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              if ((tenant['email'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      tenant['email'] as String,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ] else
              Text(
                'No tenant assigned',
                style: TextStyle(color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilySection(String title, List<dynamic> familyMembers) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...familyMembers.map((member) {
              final m = member as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    (m['name'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                title: Text(
                  m['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  m['phone'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _showEditMemberDialog(m),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.errorColor),
                      onPressed: () => _confirmRemoveMember(m),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
