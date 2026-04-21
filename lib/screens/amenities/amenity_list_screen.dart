import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final amenitiesAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(amenityServiceProvider).getAmenities();
});

class AmenityListScreen extends ConsumerWidget {
  const AmenityListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(amenitiesAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amenities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'Bookings',
            onPressed: () => context.go('/amenities/bookings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(amenitiesAdminProvider),
        child: async.when(
          data: (amenities) {
            if (amenities.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.event_available,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('No amenities configured.',
                        style:
                            TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: amenities.length,
              itemBuilder: (_, i) {
                final a = amenities[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.event_available,
                        color: AppTheme.primaryColor),
                    title: Text(a['name']?.toString() ?? 'Amenity',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      a['category']?.toString(),
                      if (a['capacity'] != null)
                        'Capacity: ${a['capacity']}',
                    ].where((e) => e != null && e.isNotEmpty).join(' \u00b7 ')),
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
