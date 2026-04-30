import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:community_admin/services/api_client.dart';

/// In-app inbox row.
///
/// Mirrors the backend `notifications` table's admin-visible columns.
/// Fields:
///   - `category` — single-source-of-truth for action sets + routes.
///   - `urgency` — `'urgent'` rows render in the top "Unread urgent"
///     section and bypass quiet-hours / mutes server-side.
///   - `isReceipt` — auto-generated rows like "You approved tenant
///     onboarding for Flat 4B". Render in the dimmed Receipts section;
///     auto-mark-read on display.
///   - `metadata` — generic JSON map for category-specific extras
///     (e.g. `attachment_urls` on monthly_report).
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String notificationType;
  final String? category;
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final String? readAt;
  final String createdAt;
  final String urgency;
  final bool isReceipt;
  final Map<String, dynamic> metadata;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    this.category,
    this.entityType,
    this.entityId,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.urgency = 'normal',
    this.isReceipt = false,
    this.metadata = const {},
  });

  AppNotification copyWith({
    bool? isRead,
    String? readAt,
  }) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      notificationType: notificationType,
      category: category,
      entityType: entityType,
      entityId: entityId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      urgency: urgency,
      isReceipt: isReceipt,
      metadata: metadata,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      notificationType: json['notification_type'] as String? ?? '',
      category: json['category'] as String?,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String,
      urgency: (json['urgency'] as String?) ?? 'normal',
      isReceipt: json['is_receipt'] as bool? ?? false,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'notification_type': notificationType,
        if (category != null) 'category': category,
        if (entityType != null) 'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
        'is_read': isRead,
        if (readAt != null) 'read_at': readAt,
        'created_at': createdAt,
        'urgency': urgency,
        'is_receipt': isReceipt,
        'metadata': metadata,
      };

  bool get isUrgent => urgency == 'urgent';

  /// Filter chip group key. Drives the inbox filter bar — admin set:
  /// "Tickets / Approvals / Announcements / Receipts / Other / All".
  String get filterGroup {
    if (isReceipt) return 'receipts';
    final cat = category ?? notificationType;
    if (cat == 'committee_escalation' ||
        cat == 'ticket_escalation' ||
        cat.startsWith('ticket') ||
        cat.startsWith('complaint')) {
      return 'tickets';
    }
    if (cat == 'approval_needed' ||
        cat == 'tenant_onboarding_pending' ||
        cat.startsWith('approval')) {
      return 'approvals';
    }
    if (cat == 'announcement' ||
        cat == 'staff_announcement' ||
        cat == 'membership_change') {
      return 'announcements';
    }
    return 'other';
  }

  String get typeIcon {
    final cat = category ?? notificationType;
    switch (cat) {
      case 'committee_escalation':
      case 'ticket_escalation':
      case 'ticket_update':
      case 'complaint_update':
        return '🎫';
      case 'approval_needed':
      case 'tenant_onboarding_pending':
        return '✅';
      case 'announcement':
      case 'staff_announcement':
        return '📢';
      case 'financial_alert':
        return '💰';
      case 'membership_change':
        return '👥';
      case 'monthly_report':
        return '📊';
      case 'custom':
        return '🔔';
      default:
        return '🔔';
    }
  }
}

class NotificationService {
  final ApiClient _api;
  NotificationService(this._api);

  static const _cacheBoxName = 'admin_notifications_cache_v1';
  static const _cacheKey = 'inbox';

  /// Load cached notifications without hitting the network. Returns
  /// an empty list if the cache box can't be opened (first launch
  /// before [persistCache] has run, or Hive init failed).
  Future<List<AppNotification>> getCached() async {
    try {
      final box = await _openCacheBox();
      final raw = box.get(_cacheKey);
      if (raw is List) {
        return raw
            .map((e) => AppNotification.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[notifCache] read failed: $e');
    }
    return const [];
  }

  /// Persist the current inbox to Hive. Called after every successful
  /// `getNotifications` so the next cold-start has fresh data.
  Future<void> persistCache(List<AppNotification> items) async {
    try {
      final box = await _openCacheBox();
      await box.put(
        _cacheKey,
        items.map((n) => n.toJson()).toList(growable: false),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[notifCache] write failed: $e');
    }
  }

  Future<Box<dynamic>> _openCacheBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) {
      return Hive.box(_cacheBoxName);
    }
    return Hive.openBox(_cacheBoxName);
  }

  Future<List<AppNotification>> getNotifications({
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final list = res.data!['data'] as List<dynamic>? ?? [];
    final parsed = list
        .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
        .toList();
    if (page == 1) {
      await persistCache(parsed);
    }
    return parsed;
  }

  Future<int> getUnreadCount() async {
    final res =
        await _api.get<Map<String, dynamic>>('/notifications/unread-count');
    return res.data!['data']?['count'] as int? ?? 0;
  }

  Future<void> markAsRead(String notificationId) async {
    await _api.post<Map<String, dynamic>>(
      '/notifications/$notificationId/read',
    );
  }

  Future<void> markAllAsRead() async {
    await _api.post<Map<String, dynamic>>('/notifications/read-all');
  }

  /// Per-user preferences. Stored on the backend's
  /// `users.notification_settings` jsonb column.
  Future<NotificationPreferences> getPreferences() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/users/me/notification-settings',
      );
      final data = res.data!['data'] as Map<String, dynamic>? ?? {};
      return NotificationPreferences.fromJson(data);
    } catch (_) {
      return const NotificationPreferences.defaults();
    }
  }

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences prefs,
  ) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/users/me/notification-settings',
      data: prefs.toJson(),
    );
    final data = res.data!['data'] as Map<String, dynamic>? ?? prefs.toJson();
    return NotificationPreferences.fromJson(data);
  }
}

/// Per-user notification preferences. Defaults: everything on, no
/// muted categories, no quiet hours.
class NotificationPreferences {
  final bool pushEnabled;
  final bool emailEnabled;
  final List<String> mutedCategories;

  /// Quiet hours in 24-hour `HH:MM` format. Both `null` means disabled.
  final String? quietStart;
  final String? quietEnd;

  /// IANA timezone (e.g. `Asia/Kolkata`). Server uses to compute the
  /// active window when filtering. Defaults to the user's profile tz.
  final String? quietTimezone;

  const NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.mutedCategories,
    required this.quietStart,
    required this.quietEnd,
    required this.quietTimezone,
  });

  const NotificationPreferences.defaults()
      : pushEnabled = true,
        emailEnabled = true,
        mutedCategories = const [],
        quietStart = null,
        quietEnd = null,
        quietTimezone = null;

  bool get hasQuietHours => quietStart != null && quietEnd != null;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    List<String>? mutedCategories,
    String? quietStart,
    String? quietEnd,
    String? quietTimezone,
    bool clearQuietHours = false,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      mutedCategories: mutedCategories ?? this.mutedCategories,
      quietStart: clearQuietHours ? null : (quietStart ?? this.quietStart),
      quietEnd: clearQuietHours ? null : (quietEnd ?? this.quietEnd),
      quietTimezone:
          clearQuietHours ? null : (quietTimezone ?? this.quietTimezone),
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final quiet = json['quiet_hours'] as Map<String, dynamic>?;
    return NotificationPreferences(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      emailEnabled: json['email_enabled'] as bool? ?? true,
      mutedCategories: ((json['muted_categories'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      quietStart: quiet?['start'] as String?,
      quietEnd: quiet?['end'] as String?,
      quietTimezone: quiet?['tz'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'push_enabled': pushEnabled,
        'email_enabled': emailEnabled,
        'muted_categories': mutedCategories,
        if (hasQuietHours)
          'quiet_hours': {
            'start': quietStart,
            'end': quietEnd,
            if (quietTimezone != null) 'tz': quietTimezone,
          },
      };
}
