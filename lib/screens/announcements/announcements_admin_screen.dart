import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final _dateFormat = DateFormat('d MMM yyyy');

final announcementsAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(announcementServiceProvider).getAnnouncements();
  final list = data['data'] as List<dynamic>? ??
      data['items'] as List<dynamic>? ??
      [];
  return list.cast<Map<String, dynamic>>();
});

class AnnouncementsAdminScreen extends ConsumerWidget {
  const AnnouncementsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(announcementsAdminProvider),
        child: async.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.campaign_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No announcements yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) => _AnnouncementCard(a: items[i]),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/announcements/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  final Map<String, dynamic> a;
  const _AnnouncementCard({required this.a});

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(announcementServiceProvider)
          .publishAnnouncement(a['id'].toString());
      ref.invalidate(announcementsAdminProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Published')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = a['title']?.toString() ?? 'Announcement';
    final body = a['body']?.toString() ?? '';
    final status = a['status']?.toString() ?? 'draft';
    final priority = a['priority']?.toString() ?? 'normal';
    final createdAt = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final isUrgent = priority == 'urgent' || priority == 'high';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (status == 'published'
                            ? AppTheme.successColor
                            : Colors.grey)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: status == 'published'
                          ? AppTheme.successColor
                          : Colors.grey.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (isUrgent)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.priority_high, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(priority.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (createdAt != null)
                  Text(
                    _dateFormat.format(createdAt),
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                const Spacer(),
                if (status == 'draft')
                  TextButton.icon(
                    onPressed: () => _publish(context, ref),
                    icon: const Icon(Icons.publish, size: 18),
                    label: const Text('Publish'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
