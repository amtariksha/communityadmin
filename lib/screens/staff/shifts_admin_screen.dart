import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final adminShiftsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(staffServiceProvider).getShifts();
});

class ShiftsAdminScreen extends ConsumerWidget {
  const ShiftsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminShiftsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shifts')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminShiftsProvider),
        child: async.when(
          data: (shifts) {
            if (shifts.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.schedule,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No shifts configured. Use the web dashboard to create shifts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shifts.length,
              itemBuilder: (_, i) {
                final s = shifts[i];
                final name = s['name']?.toString() ?? 'Shift';
                final startTime = s['start_time']?.toString() ?? '';
                final endTime = s['end_time']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.schedule,
                        color: AppTheme.primaryColor),
                    title: Text(name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$startTime \u2013 $endTime'),
                  ),
                );
              },
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
