import 'dart:async';
import 'dart:io';
import 'package:community_admin/services/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM integration for the admin app (facility-manager phone).
///
/// Lifecycle mirrors the resident/guard apps:
///   - [init] on startup → permission + listeners
///   - [registerAfterLogin] after auth → POST /notifications/devices
///   - [unregisterBeforeLogout] before clearing creds → DELETE token
class PushService {
  final ApiClient _api;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  String? _currentToken;

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
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _foregroundSub = FirebaseMessaging.onMessage.listen((msg) {
        if (kDebugMode) {
          debugPrint('[push] foreground ${msg.messageId}: ${msg.data}');
        }
      });

      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        final route = routeForNotification(msg.data);
        if (route != null) _tapRouteController.add(route);
      });

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final route = routeForNotification(initial.data);
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
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _refreshSub?.cancel();
    await _tapRouteController.close();
  }
}

String? routeForNotification(Map<String, dynamic> data) {
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
