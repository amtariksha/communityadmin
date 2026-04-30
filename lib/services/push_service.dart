import 'dart:async';
import 'dart:io';
import 'package:community_admin/core/notifications/categories.dart';
import 'package:community_admin/core/notifications/local_notifications_service.dart';
import 'package:community_admin/services/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM integration for the admin app (committee-member / facility-manager phone).
///
/// Lifecycle mirrors the resident/guard apps:
///   - [init] on startup → permission + listeners + foreground re-render
///   - [registerAfterLogin] after auth → POST /notifications/devices
///   - [unregisterBeforeLogout] before clearing creds → DELETE token
///   - [subscribeToTopics] / [unsubscribeFromAllTopics] for tenant-scoped
///     audience broadcasts. Topic format: `tenant-${id}` and
///     `tenant-${id}-role-${role}` (e.g. `committee_member`).
class PushService {
  final ApiClient _api;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  String? _currentToken;

  /// Topics this device is currently subscribed to. Tracked locally so
  /// [unsubscribeFromAllTopics] can pull them off without re-fetching
  /// from the server.
  final Set<String> _activeTopics = <String>{};

  final StreamController<String> _tapRouteController =
      StreamController<String>.broadcast();

  PushService(this._api);

  Stream<String> get onTapRoute => _tapRouteController.stream;

  Future<void> init() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (Platform.isIOS) {
        // Suppress the OS auto-render for foreground messages so we
        // can re-render via flutter_local_notifications with action
        // buttons attached. Background path already routes through
        // _firebaseBackgroundHandler.
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
      }

      _foregroundSub = FirebaseMessaging.onMessage.listen((msg) async {
        if (kDebugMode) {
          debugPrint('[push] foreground ${msg.messageId}: ${msg.data}');
        }
        // Re-render via local notifications so the user sees category
        // action buttons. Mirror title/body from `msg.notification`
        // when only the rich shape was sent.
        final data = Map<String, dynamic>.from(msg.data);
        final notif = msg.notification;
        if (notif != null) {
          if (!data.containsKey('title') && notif.title != null) {
            data['title'] = notif.title;
          }
          if (!data.containsKey('body') && notif.body != null) {
            data['body'] = notif.body;
          }
        }
        if (data.isNotEmpty) {
          await LocalNotificationsService.instance.show(data);
        }
      });

      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        final route = routeForData(msg.data) ?? routeForLegacy(msg.data);
        if (route != null) _tapRouteController.add(route);
      });

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final route = routeForData(initial.data) ?? routeForLegacy(initial.data);
        if (route != null) _tapRouteController.add(route);
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[push] init failed: $e\n$st');
    }
  }

  Future<void> registerAfterLogin({String? deviceName}) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        if (kDebugMode) debugPrint('[push] getToken returned null');
        return;
      }
      _currentToken = token;
      await _register(token, deviceName: deviceName);

      _refreshSub?.cancel();
      _refreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        await _register(newToken, deviceName: deviceName);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[push] register failed: $e');
    }
  }

  Future<void> _register(String token, {String? deviceName}) async {
    await _api.post<Map<String, dynamic>>(
      '/notifications/devices',
      data: {
        'device_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        if (deviceName != null) 'device_name': deviceName,
      },
    );
  }

  Future<void> unregisterBeforeLogout() async {
    final token = _currentToken ?? await _messaging.getToken();
    if (token == null) return;
    try {
      await _api.delete<Map<String, dynamic>>(
        '/notifications/devices?token=$token',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[push] unregister failed: $e');
    }
    _currentToken = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    await unsubscribeFromAllTopics();
  }

  /// Subscribe FCM topics for the current tenant + role. The admin's
  /// committee role uses underscore in the slug (`committee_member`)
  /// per the backend audience resolver — `_sanitize` preserves
  /// underscores, only normalising case + non-alphanumerics.
  Future<void> subscribeToTopics({
    required String tenantId,
    String? role,
  }) async {
    final topics = <String>[
      'tenant-$tenantId',
      if (role != null && role.isNotEmpty)
        'tenant-$tenantId-role-${_sanitize(role)}',
    ];
    for (final topic in topics) {
      try {
        await _messaging.subscribeToTopic(topic);
        _activeTopics.add(topic);
      } catch (e) {
        if (kDebugMode) debugPrint('[push] subscribe $topic failed: $e');
      }
    }
  }

  Future<void> unsubscribeFromAllTopics() async {
    for (final topic in _activeTopics.toList()) {
      try {
        await _messaging.unsubscribeFromTopic(topic);
      } catch (e) {
        if (kDebugMode) debugPrint('[push] unsubscribe $topic failed: $e');
      }
    }
    _activeTopics.clear();
  }

  /// FCM topic names accept `[a-zA-Z0-9-_.~%]+`. We lowercase and
  /// replace any other character with `-`. Underscores and digits pass
  /// through untouched, which is what the backend expects for slugs
  /// like `committee_member`.
  String _sanitize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _refreshSub?.cancel();
    await _tapRouteController.close();
  }
}

/// Legacy route resolver — kept for backward compat with payloads that
/// still carry `data.type` instead of `data.category`. Categories.dart
/// already shims via `kLegacyTypeToCategory`, but if a payload arrives
/// with a fully unknown type we want to at least open a list view
/// rather than no-op.
String? routeForLegacy(Map<String, dynamic> data) {
  final type = data['type']?.toString();
  final entityId = data['entity_id']?.toString();
  switch (type) {
    case 'ticket':
      return entityId != null ? '/tickets/$entityId' : '/tickets';
    case 'approval':
      return '/approvals';
    case 'leave':
      return '/staff/leaves';
    case 'announcement':
      return '/announcements';
    default:
      return null;
  }
}
