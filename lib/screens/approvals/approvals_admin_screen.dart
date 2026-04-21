import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final _dateFormat = DateFormat('d MMM yyyy');

final approvalsListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, status) async {
  final data =
      await ref.read(approvalServiceProvider).getRequests(status: status);
  final list = data['data'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
});

class ApprovalsAdminScreen extends ConsumerStatefulWidget {
  const ApprovalsAdminScreen({super.key});

  @override
  ConsumerState<ApprovalsAdminScreen> createState() =>
      _ApprovalsAdminScreenState();
}

class _ApprovalsAdminScreenState
    extends ConsumerState<ApprovalsAdminScreen> {
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(approvalsListProvider(_status));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _status = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(
                  value: 'partially_approved',
                  child: Text('Partially approved')),
              PopupMenuItem(value: 'approved', child: Text('Approved')),
              PopupMenuItem(value: 'rejected', child: Text('Rejected')),
              PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(approvalsListProvider(_status)),
        child: async.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.task_alt_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('No $_status approvals.',
                        style:
                            TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) => _RequestCard(
                request: items[i],
                currentStatus: _status,
              ),
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

class _RequestCard extends ConsumerWidget {
  final Map<String, dynamic> request;
  final String currentStatus;
  const _RequestCard({required this.request, required this.currentStatus});

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(approvalServiceProvider)
          .approve(request['id'].toString());
      ref.invalidate(approvalsListProvider(currentStatus));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Reason (required)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(ctx, text);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ref
          .read(approvalServiceProvider)
          .reject(request['id'].toString(), reason: reason);
      ref.invalidate(approvalsListProvider(currentStatus));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  String _prettyType(String s) => s
      .split('_')
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = request['request_type']?.toString() ?? '';
    final summary = request['entity_summary']?.toString();
    final requester = request['requester_name']?.toString();
    final createdAt =
        DateTime.tryParse(request['created_at']?.toString() ?? '');
    final level = request['approval_level'];
    final maxLevels = request['max_levels'];
    final isPending = currentStatus == 'pending' ||
        currentStatus == 'partially_approved';

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
                  child: Text(_prettyType(type),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                if (level != null && maxLevels != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'L$level/$maxLevels',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(summary),
            ],
            if (requester != null) ...[
              const SizedBox(height: 6),
              Text('Requested by $requester',
                  style:
                      TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(_dateFormat.format(createdAt),
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _reject(context, ref),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _approve(context, ref),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
