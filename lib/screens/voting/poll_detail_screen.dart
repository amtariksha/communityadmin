import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/screens/voting/polls_admin_screen.dart';

final pollDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(votingServiceProvider).getPoll(id);
});

class PollDetailScreen extends ConsumerWidget {
  final String pollId;
  const PollDetailScreen({super.key, required this.pollId});

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(votingServiceProvider).closePoll(pollId);
      ref.invalidate(pollDetailProvider(pollId));
      ref.invalidate(pollsAdminProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll closed')),
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
    final async = ref.watch(pollDetailProvider(pollId));

    return Scaffold(
      appBar: AppBar(title: const Text('Poll')),
      body: async.when(
        data: (poll) {
          final title = poll['title']?.toString() ?? 'Poll';
          final desc = poll['description']?.toString();
          final status = poll['status']?.toString() ?? 'draft';
          final options = (poll['options'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          final totalVotes = poll['total_votes'] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (desc != null && desc.isNotEmpty)
                Text(desc, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
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
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text('$totalVotes total votes'),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Results',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final o in options) _OptionBar(
                option: o,
                totalVotes: totalVotes is num ? totalVotes.toInt() : 0,
              ),
              const SizedBox(height: 24),
              if (status == 'open')
                OutlinedButton.icon(
                  onPressed: () => _close(context, ref),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Close poll'),
                ),
            ],
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
    );
  }
}

class _OptionBar extends StatelessWidget {
  final Map<String, dynamic> option;
  final int totalVotes;
  const _OptionBar({required this.option, required this.totalVotes});

  @override
  Widget build(BuildContext context) {
    final label = option['label']?.toString() ?? '';
    final votes = (option['votes'] as num?)?.toInt() ?? 0;
    final pct = totalVotes == 0 ? 0.0 : (votes / totalVotes);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              Text('$votes (${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
