import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:community_admin/core/notifications/categories.dart';

/// Wraps `flutter_local_notifications` to render FCM data-only payloads
/// with category-aware action buttons.
///
/// Usage:
///   1. `await LocalNotificationsService.instance.init(...)` from
///      `main()` after `Firebase.initializeApp`.
///   2. From the FCM listener (foreground or background isolate), call
///      `show(payload)` with the message data.
///
/// iOS:
///   - Each category in [kAdminCategories] is registered as a
///     `DarwinNotificationCategory` with the corresponding action set
///     at init time. **Cannot register categories post-launch on iOS,
///     so this list is fixed at startup.**
///   - Destructive actions get the `.destructive` option for red-text
///     rendering on the lock screen.
///
/// Android:
///   - One `AndroidNotificationChannel` per category id.
///   - Actions render as buttons under the body.
///   - Notifications group by `groupKey: 'tenant-{tenantId}'` so the
///     stack collapses on the shade.
class LocalNotificationsService {
  LocalNotificationsService._();
  static final instance = LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(NotificationResponse)? _onForegroundResponse;

  /// Must be awaited once before any `show()` call. The
  /// `onForegroundResponse` is invoked when the user taps a
  /// notification or one of its actions while the app is foregrounded
  /// or the OS rehydrates the same isolate.
  ///
  /// `onBackgroundResponse` MUST be a top-level
  /// `@pragma('vm:entry-point')` function — Flutter looks it up by
  /// name in the background isolate and refuses closures.
  Future<void> init({
    required void Function(NotificationResponse) onForegroundResponse,
    required void Function(NotificationResponse) onBackgroundResponse,
  }) async {
    if (_initialized) return;
    _onForegroundResponse = onForegroundResponse;

    final androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: _buildIosCategories(),
    );

    await _plugin.initialize(
      InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: (response) {
        _onForegroundResponse?.call(response);
      },
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    if (androidPlugin != null) {
      for (final descriptor in kAdminCategories.values) {
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            descriptor.id,
            _channelNameFor(descriptor.id),
            description: 'ezegate Admin ${descriptor.id} notifications',
            importance: descriptor.actions.isNotEmpty
                ? Importance.high
                : Importance.defaultImportance,
          ),
        );
      }
    }

    _initialized = true;
  }

  /// Render a local notification from an FCM-style data payload.
  ///
  /// The `data` map MUST contain at least `title` and `body` strings;
  /// `category` and `entity_id` drive action sets and tap routing.
  /// The full data map is JSON-encoded into the notification's
  /// `payload` so the tap callback can rehydrate it.
  Future<void> show(Map<String, dynamic> data) async {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('[localNotif] show() before init() — skipping');
      }
      return;
    }
    final title = (data['title'] ?? 'ezegate Admin').toString();
    final body = (data['body'] ?? '').toString();
    final categoryId = resolveCategory(data);
    final descriptor = kAdminCategories[categoryId];
    if (descriptor == null) return;

    final tenantId = (data['thread_id'] ?? data['tenant_id'] ?? '').toString();

    final androidActions = descriptor.actions
        .map((a) => AndroidNotificationAction(
              a.id,
              a.label,
              showsUserInterface: a.foreground,
              cancelNotification: !a.foreground,
              inputs: a.inputPrompt != null
                  ? [
                      AndroidNotificationActionInput(
                        label: a.inputPrompt!.placeholder,
                        allowFreeFormInput: true,
                      ),
                    ]
                  : const <AndroidNotificationActionInput>[],
            ))
        .toList();

    final androidDetails = AndroidNotificationDetails(
      descriptor.id,
      _channelNameFor(descriptor.id),
      channelDescription: 'ezegate Admin ${descriptor.id} notifications',
      importance: descriptor.actions.isNotEmpty
          ? Importance.high
          : Importance.defaultImportance,
      priority: Priority.high,
      groupKey: tenantId.isNotEmpty ? 'tenant-$tenantId' : null,
      actions: androidActions,
    );

    final iosDetails = DarwinNotificationDetails(
      categoryIdentifier: descriptor.id,
      threadIdentifier: tenantId.isNotEmpty ? 'tenant-$tenantId' : null,
    );

    final id = _stableIdFor(data);
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  List<DarwinNotificationCategory> _buildIosCategories() {
    return kAdminCategories.values.map((descriptor) {
      final actions = <DarwinNotificationAction>[];
      for (final a in descriptor.actions) {
        final options = <DarwinNotificationActionOption>{
          if (a.foreground) DarwinNotificationActionOption.foreground,
          if (a.destructive) DarwinNotificationActionOption.destructive,
          if (a.requiresBiometric)
            DarwinNotificationActionOption.authenticationRequired,
        };
        if (a.inputPrompt != null) {
          actions.add(
            DarwinNotificationAction.text(
              a.id,
              a.label,
              buttonTitle: 'Send',
              placeholder: a.inputPrompt!.placeholder,
              options: options,
            ),
          );
        } else {
          actions.add(
            DarwinNotificationAction.plain(
              a.id,
              a.label,
              options: options,
            ),
          );
        }
      }
      return DarwinNotificationCategory(
        descriptor.id,
        actions: actions,
        options: const {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
      );
    }).toList();
  }

  /// Stable-ish numeric id derived from `entity_id` + category so the
  /// same logical event collapses to one notification (an updated
  /// approval replaces the old card instead of stacking).
  int _stableIdFor(Map<String, dynamic> data) {
    final entity = (data['entity_id'] ?? '').toString();
    final category = (data['category'] ?? '').toString();
    final key = '$category:$entity';
    if (key.length < 2) return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    return key.hashCode & 0x7fffffff;
  }

  String _channelNameFor(String id) {
    switch (id) {
      case 'committee_escalation':
        return 'Committee escalations';
      case 'approval_needed':
        return 'Approvals';
      case 'announcement':
        return 'Announcements';
      case 'ticket_escalation':
        return 'Ticket escalations';
      case 'tenant_onboarding_pending':
        return 'Tenant onboarding';
      case 'financial_alert':
        return 'Financial alerts';
      case 'membership_change':
        return 'Membership updates';
      case 'monthly_report':
        return 'Monthly reports';
      default:
        return id;
    }
  }
}
