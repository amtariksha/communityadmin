import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final metersAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(utilityServiceProvider).getMeters();
});

class MetersAdminScreen extends ConsumerWidget {
  const MetersAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(metersAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Utility Meters')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(metersAdminProvider),
        child: async.when(
          data: (meters) {
            if (meters.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.speed,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No meters configured. Use the web dashboard to add meters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: meters.length,
              itemBuilder: (_, i) {
                final m = meters[i];
                final type = m['meter_type']?.toString() ?? '';
                final number = m['meter_number']?.toString() ?? '';
                final unitNumber = m['unit_number']?.toString();
                IconData icon;
                Color color;
                switch (type) {
                  case 'water':
                    icon = Icons.water_drop_outlined;
                    color = Colors.blue;
                    break;
                  case 'electricity':
                    icon = Icons.bolt_outlined;
                    color = Colors.amber.shade700;
                    break;
                  case 'gas':
                    icon = Icons.local_fire_department_outlined;
                    color = Colors.deepOrange;
                    break;
                  default:
                    icon = Icons.speed;
                    color = AppTheme.primaryColor;
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(icon, color: color),
                    title: Text(
                      '${_capitalize(type)} \u00b7 Meter #$number',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: unitNumber != null
                        ? Text('Unit $unitNumber')
                        : null,
                    trailing: TextButton.icon(
                      onPressed: () => context.go(
                        '/utility/reading?meter_id=${m['id']}&type=$type',
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Reading'),
                    ),
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

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
