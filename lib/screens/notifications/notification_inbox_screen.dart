import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/core/notifications/categories.dart';
import 'package:community_admin/providers/notification_provider.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin notification inbox.
///
/// Sections (in render order):
///   1. **Unread urgent** — never collapsed; red banner header.
///   2. **Unread** — chronological.
///   3. **Read** — collapsed by default.
///   4. **Receipts** — collapsed by default; auto-mark-read on display.
///
/// Filter chips: All / Tickets / Approvals / Announcements / Receipts.
///
/// Tap a row → marks read + routes via `routeForData` (catalog-driven).
/// Inbox cards for `monthly_report` render Download buttons per
/// attachment URL via `url_launcher`.
class NotificationInboxScreen extends ConsumerStatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  ConsumerState<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

enum _Filter { all, tickets, approvals, announcements, receipts }

class _NotificationInboxScreenState
    extends ConsumerState<NotificationInboxScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  _Filter _activeFilter = _Filter.all;
  bool _readExpanded = false;
  bool _receiptsExpanded = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Two-phase load: cache → server. The cache renders instantly for
  /// usable offline UX; the network fetch reconciles + persists.
  Future<void> _bootstrap() async {
    final service = ref.read(notificationServiceProvider);
    try {
      final cached = await service.getCached();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _notifications = cached;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Cache miss is fine — proceed to live fetch.
    }
    await _load(silent: _notifications.isNotEmpty);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final service = ref.read(notificationServiceProvider);
      final items = await service.getNotifications(limit: 50);
      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        if (silent && _notifications.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Showing cached inbox · $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      final service = ref.read(notificationServiceProvider);
      await service.markAllAsRead();
      ref.invalidate(unreadNotificationCountProvider);
      _load();
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      final service = ref.read(notificationServiceProvider);
      await service.markAsRead(notification.id);
      ref.invalidate(unreadNotificationCountProvider);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notification.id);
        if (idx >= 0) {
          _notifications[idx] = notification.copyWith(
            isRead: true,
            readAt: DateTime.now().toIso8601String(),
          );
        }
      });
    } catch (_) {
      // Optimistic UI; ignore.
    }
  }

  String? _routeFor(AppNotification n) {
    final data = <String, dynamic>{
      if (n.category != null) 'category': n.category,
      'notification_type': n.notificationType,
      if (n.entityId != null) 'entity_id': n.entityId,
      if (n.entityType != null) 'entity_type': n.entityType,
    };
    return routeForData(data);
  }

  Future<void> _onTap(AppNotification n) async {
    await _markRead(n);
    final route = _routeFor(n);
    if (route != null && mounted) {
      context.push(route);
    }
  }

  /// Parse `attachment_urls` from a monthly_report metadata blob.
  List<String> _attachmentUrls(AppNotification n) {
    final raw = n.metadata['attachment_urls'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $e')),
      );
    }
  }

  bool _matchesFilter(AppNotification n) {
    if (_activeFilter == _Filter.all) {
      // Receipts excluded from "All" — they have their own section.
      return !n.isReceipt;
    }
    final group = n.filterGroup;
    switch (_activeFilter) {
      case _Filter.tickets:
        return group == 'tickets';
      case _Filter.approvals:
        return group == 'approvals';
      case _Filter.announcements:
        return group == 'announcements';
      case _Filter.receipts:
        return n.isReceipt;
      case _Filter.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where(_matchesFilter).toList();

    final urgentUnread = filtered
        .where((n) => !n.isRead && n.isUrgent && !n.isReceipt)
        .toList();
    final unread = filtered
        .where((n) => !n.isRead && !n.isUrgent && !n.isReceipt)
        .toList();
    final read = filtered.where((n) => n.isRead && !n.isReceipt).toList();
    final receipts =
        _notifications.where((n) => n.isReceipt && _matchesFilter(n)).toList();

    final unreadCount = urgentUnread.length + unread.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _filterChipBar()),
                      if (urgentUnread.isEmpty &&
                          unread.isEmpty &&
                          read.isEmpty &&
                          receipts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _emptyState(),
                        ),
                      if (urgentUnread.isNotEmpty)
                        _section(
                          label: 'Urgent',
                          accent: AppTheme.errorColor,
                          items: urgentUnread,
                        ),
                      if (unread.isNotEmpty)
                        _section(
                          label: 'New',
                          accent: AppTheme.primaryColor,
                          items: unread,
                        ),
                      if (read.isNotEmpty)
                        _collapsibleSection(
                          label: 'Read',
                          countLabel: 'Show ${read.length} read',
                          expanded: _readExpanded,
                          onToggle: () => setState(
                            () => _readExpanded = !_readExpanded,
                          ),
                          items: read,
                        ),
                      if (receipts.isNotEmpty)
                        _collapsibleSection(
                          label: 'Receipts',
                          countLabel: 'Show ${receipts.length} receipts',
                          expanded: _receiptsExpanded,
                          onToggle: () => setState(
                            () => _receiptsExpanded = !_receiptsExpanded,
                          ),
                          items: receipts,
                          dimmed: true,
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 32),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section + filter chip helpers
  // ---------------------------------------------------------------------------

  Widget _filterChipBar() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final f in _Filter.values) ...[
            _FilterChipButton(
              label: _filterLabel(f),
              selected: _activeFilter == f,
              onTap: () => setState(() => _activeFilter = f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'All';
      case _Filter.tickets:
        return 'Tickets';
      case _Filter.approvals:
        return 'Approvals';
      case _Filter.announcements:
        return 'Announcements';
      case _Filter.receipts:
        return 'Receipts';
    }
  }

  SliverList _section({
    required String label,
    required Color accent,
    required List<AppNotification> items,
  }) {
    return SliverList.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$label · ${items.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        for (final n in items)
          _NotificationRow(
            notification: n,
            timeLabel: _formatTime(n.createdAt),
            attachments: _attachmentUrls(n),
            onTap: () => _onTap(n),
            onAttachmentTap: _openUrl,
          ),
      ],
    );
  }

  SliverList _collapsibleSection({
    required String label,
    required String countLabel,
    required bool expanded,
    required VoidCallback onToggle,
    required List<AppNotification> items,
    bool dimmed = false,
  }) {
    return SliverList.list(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '· $countLabel',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final n in items)
            _NotificationRow(
              notification: n,
              timeLabel: _formatTime(n.createdAt),
              attachments: _attachmentUrls(n),
              dimmed: dimmed,
              onTap: () => _onTap(n),
              onAttachmentTap: _openUrl,
            ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            "You\u2019re all caught up.",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return isoString;
    }
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.primaryColor : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final String timeLabel;
  final VoidCallback onTap;
  final List<String> attachments;
  final void Function(String url) onAttachmentTap;
  final bool dimmed;

  const _NotificationRow({
    required this.notification,
    required this.timeLabel,
    required this.onTap,
    required this.attachments,
    required this.onAttachmentTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final bg = isUnread
        ? const Color(0xFFFFF9ED)
        : (dimmed ? AppTheme.surfaceColor : Colors.transparent);
    final isMonthlyReport =
        (notification.category ?? notification.notificationType) ==
            'monthly_report';

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unread dot column.
                  SizedBox(
                    width: 8,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: isUnread && !dimmed
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: notification.isUrgent
                                    ? AppTheme.errorColor
                                    : AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Type icon — emoji glyph from the model.
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      notification.typeIcon,
                      style: TextStyle(
                        fontSize: 22,
                        color: dimmed ? Colors.grey.shade500 : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: dimmed
                                      ? Colors.grey.shade700
                                      : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 14,
                            color: dimmed
                                ? Colors.grey.shade500
                                : Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isMonthlyReport && attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final url in attachments)
                        OutlinedButton.icon(
                          onPressed: () => onAttachmentTap(url),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: Text(_attachmentLabel(url)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(
                                color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _attachmentLabel(String url) {
    try {
      final uri = Uri.parse(url);
      final segs = uri.pathSegments;
      if (segs.isEmpty) return 'Download';
      final name = segs.last;
      if (name.length > 24) {
        return '${name.substring(0, 24)}…';
      }
      return name;
    } catch (_) {
      return 'Download';
    }
  }
}
