import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final leaveRequestsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String?>((ref, status) async {
  return ref.read(staffServiceProvider).getLeaves(status: status);
});

class LeaveApprovalsScreen extends ConsumerStatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  ConsumerState<LeaveApprovalsScreen> createState() =>
      _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState
    extends ConsumerState<LeaveApprovalsScreen> {
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    final leavesAsync = ref.watch(leaveRequestsProvider(_status));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Leaves'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _status = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'approved', child: Text('Approved')),
              PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(leaveRequestsProvider(_status)),
        child: leavesAsync.when(
          data: (leaves) {
            if (leaves.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.event_busy,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('No $_status leaves.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leaves.length,
              itemBuilder: (_, i) => _LeaveCard(
                leave: leaves[i],
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

class _LeaveCard extends ConsumerWidget {
  final Map<String, dynamic> leave;
  final String currentStatus;
  const _LeaveCard({required this.leave, required this.currentStatus});

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(staffServiceProvider)
          .approveLeave(leave['id'].toString());
      ref.invalidate(leaveRequestsProvider(currentStatus));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await _promptReason(context);
    if (reason == null || reason.isEmpty) return;
    try {
      await ref
          .read(staffServiceProvider)
          .rejectLeave(leave['id'].toString(), reason: reason);
      ref.invalidate(leaveRequestsProvider(currentStatus));
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
    final staffName = leave['staff_name']?.toString() ?? 'Staff';
    final leaveType = leave['leave_type']?.toString() ?? '';
    final startDate = leave['start_date']?.toString() ?? '';
    final endDate = leave['end_date']?.toString() ?? '';
    final reason = leave['reason']?.toString();
    final status = leave['status']?.toString() ?? 'pending';

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
                  child: Text(staffName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('$leaveType \u00b7 $startDate \u2192 $endDate',
                style: const TextStyle(fontSize: 13)),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(reason,
                  style:
                      TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
            if (status == 'pending') ...[
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

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

Future<String?> _promptReason(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reject Leave'),
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
    ),
  );
}
