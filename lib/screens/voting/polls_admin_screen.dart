import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final _dateFormat = DateFormat('d MMM yyyy');

final pollsAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(votingServiceProvider).getPolls();
});

class PollsAdminScreen extends ConsumerWidget {
  const PollsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pollsAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Polls')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pollsAdminProvider),
        child: async.when(
          data: (polls) {
            if (polls.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.how_to_vote,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No polls yet. Use the web dashboard to create polls.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: polls.length,
              itemBuilder: (_, i) {
                final p = polls[i];
                final id = p['id']?.toString() ?? '';
                final title = p['title']?.toString() ?? 'Poll';
                final status = p['status']?.toString() ?? 'draft';
                final totalVotes = p['total_votes'] ?? 0;
                final end = DateTime.tryParse(p['voting_end']?.toString() ?? '');

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => context.go('/polls/$id'),
                    title: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (end != null)
                        'Ends ${_dateFormat.format(end)}',
                      '$totalVotes votes',
                    ].join(' \u00b7 ')),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (status == 'open'
                                ? AppTheme.successColor
                                : Colors.grey)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(
                            color: status == 'open'
                                ? AppTheme.successColor
                                : Colors.grey.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
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
}
