import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/service_providers.dart';

final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

final bookingsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String?>((ref, status) async {
  return ref.read(amenityServiceProvider).getBookings(status: status);
});

class BookingQueueScreen extends ConsumerStatefulWidget {
  const BookingQueueScreen({super.key});

  @override
  ConsumerState<BookingQueueScreen> createState() =>
      _BookingQueueScreenState();
}

class _BookingQueueScreenState extends ConsumerState<BookingQueueScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookingsProvider(_status));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amenity Bookings'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _status = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('All')),
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
              PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(bookingsProvider(_status)),
        child: async.when(
          data: (bookings) {
            if (bookings.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.event_busy,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('No bookings.',
                        style:
                            TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (_, i) =>
                  _BookingCard(booking: bookings[i], currentStatus: _status),
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

class _BookingCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final String? currentStatus;
  const _BookingCard({required this.booking, required this.currentStatus});

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed':
        return AppTheme.successColor;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(amenityServiceProvider)
          .cancelBooking(booking['id'].toString());
      ref.invalidate(bookingsProvider(currentStatus));
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
    final amenityName = booking['amenity_name']?.toString() ?? 'Amenity';
    final memberName = booking['member_name']?.toString() ?? 'Member';
    final unitNumber = booking['unit_number']?.toString();
    final startAt = DateTime.tryParse(booking['start_at']?.toString() ?? '');
    final endAt = DateTime.tryParse(booking['end_at']?.toString() ?? '');
    final status = booking['status']?.toString() ?? 'pending';

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
                    amenityName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          color: _statusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$memberName${unitNumber != null ? ' \u00b7 Unit $unitNumber' : ''}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            if (startAt != null && endAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '${_dateFormat.format(startAt)} \u2192 ${_dateFormat.format(endAt)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (status != 'cancelled') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _cancel(context, ref),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
