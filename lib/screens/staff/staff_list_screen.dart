import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final staffEmployeesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(staffServiceProvider).getEmployees();
  final list = data['data'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
});

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffEmployeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'Leaves',
            onPressed: () => context.go('/staff/leaves'),
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'Shifts',
            onPressed: () => context.go('/staff/shifts'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(staffEmployeesProvider),
        child: async.when(
          data: (employees) {
            if (employees.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.badge_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No staff yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: employees.length,
              itemBuilder: (_, i) => _EmployeeCard(e: employees[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> e;
  const _EmployeeCard({required this.e});

  @override
  Widget build(BuildContext context) {
    final name = e['name']?.toString() ?? 'Staff';
    final staffType = e['staff_type']?.toString() ?? '';
    final phone = e['phone']?.toString();
    final isActive = e['is_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive ? AppTheme.primaryColor : Colors.grey.shade300,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(name),
        subtitle: Text(
          [staffType, if (phone != null) phone]
              .where((s) => s.isNotEmpty)
              .join(' \u00b7 '),
        ),
        trailing: isActive
            ? null
            : const Text('INACTIVE',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
      ),
    );
  }
}
