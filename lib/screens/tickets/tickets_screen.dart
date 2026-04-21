import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final _dateFormat = DateFormat('d MMM yyyy');

final ticketsProvider = FutureProvider.family<List<Map<String, dynamic>>,
    String?>((ref, status) async {
  final data =
      await ref.read(ticketServiceProvider).getTickets(status: status);
  final list = data['data'] as List<dynamic>? ??
      data['items'] as List<dynamic>? ??
      [];
  return list.cast<Map<String, dynamic>>();
});

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketsProvider(_filterStatus));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _filterStatus = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('All')),
              PopupMenuItem(value: 'open', child: Text('Open')),
              PopupMenuItem(value: 'in_progress', child: Text('In progress')),
              PopupMenuItem(value: 'resolved', child: Text('Resolved')),
              PopupMenuItem(value: 'closed', child: Text('Closed')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(ticketsProvider(_filterStatus)),
        child: ticketsAsync.when(
          data: (tickets) {
            if (tickets.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.support_agent,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _filterStatus == null
                          ? 'No tickets yet.'
                          : 'No $_filterStatus tickets.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              itemBuilder: (_, i) => _TicketCard(ticket: tickets[i]),
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
        onPressed: () => context.go('/tickets/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _TicketCard({required this.ticket});

  Color get _statusColor {
    switch (ticket['status']) {
      case 'resolved':
      case 'closed':
        return AppTheme.successColor;
      case 'in_progress':
        return Colors.blue;
      case 'reopened':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  Color get _priorityColor {
    switch (ticket['priority']) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.deepOrange;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ticket['id']?.toString() ?? '';
    final subject = ticket['subject']?.toString() ?? 'Ticket';
    final category = ticket['category']?.toString() ?? '';
    final status = ticket['status']?.toString() ?? 'open';
    final priority = ticket['priority']?.toString() ?? 'medium';
    final createdAt = DateTime.tryParse(ticket['created_at']?.toString() ?? '');
    final unitNumber = ticket['unit_number']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.go('/tickets/$id'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _Pill(label: category, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  _Pill(
                    label: priority,
                    color: _priorityColor,
                  ),
                  if (unitNumber != null) ...[
                    const SizedBox(width: 6),
                    _Pill(label: 'Unit $unitNumber', color: Colors.teal),
                  ],
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  _dateFormat.format(createdAt),
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
