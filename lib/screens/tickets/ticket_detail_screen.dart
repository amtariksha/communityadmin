import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/screens/tickets/tickets_screen.dart';

final ticketDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(ticketServiceProvider).getTicket(id);
});

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _commentController = TextEditingController();
  bool _postingComment = false;
  bool _updating = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(String status) async {
    setState(() => _updating = true);
    try {
      await ref.read(ticketServiceProvider).updateTicket(
            widget.ticketId,
            status: status,
          );
      ref.invalidate(ticketDetailProvider(widget.ticketId));
      ref.invalidate(ticketsProvider(null));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _postComment() async {
    final msg = _commentController.text.trim();
    if (msg.isEmpty) return;
    setState(() => _postingComment = true);
    try {
      await ref
          .read(ticketServiceProvider)
          .addComment(widget.ticketId, message: msg);
      _commentController.clear();
      ref.invalidate(ticketDetailProvider(widget.ticketId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(ticketDetailProvider(widget.ticketId));
    final dateFormat = DateFormat('d MMM yyyy, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket'),
        actions: [
          if (_updating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: _changeStatus,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Mark Open')),
                PopupMenuItem(
                    value: 'in_progress', child: Text('In Progress')),
                PopupMenuItem(value: 'resolved', child: Text('Resolved')),
                PopupMenuItem(value: 'closed', child: Text('Closed')),
              ],
            ),
        ],
      ),
      body: ticketAsync.when(
        data: (ticket) {
          final comments =
              (ticket['comments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                  [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket['subject']?.toString() ?? 'Ticket',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          _Chip(
                              label: ticket['status']?.toString() ?? 'open',
                              color: Colors.blue),
                          _Chip(
                              label: ticket['priority']?.toString() ?? 'medium',
                              color: Colors.orange),
                          _Chip(
                              label: ticket['category']?.toString() ?? 'general',
                              color: Colors.teal),
                        ],
                      ),
                      if (ticket['description'] != null) ...[
                        const SizedBox(height: 12),
                        Text(ticket['description'].toString()),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Comments',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No comments yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              for (final c in comments)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              c['author_name']?.toString() ?? 'User',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const Spacer(),
                            if (c['created_at'] != null)
                              Text(
                                dateFormat.format(DateTime.parse(
                                    c['created_at'].toString())),
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 11),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(c['message']?.toString() ?? ''),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment\u2026',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _postingComment ? null : _postComment,
                    icon: _postingComment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
