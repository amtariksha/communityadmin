import 'package:community_admin/services/api_client.dart';

/// Scaffolding for FCM push integration. Ships without firebase_core /
/// firebase_messaging imports so the app continues to build until the
/// Firebase project is configured. When ready:
///
/// 1. `flutterfire configure` from app root.
/// 2. In `main.dart`, before `runApp`:
///       WidgetsFlutterBinding.ensureInitialized();
///       await Firebase.initializeApp(
///         options: DefaultFirebaseOptions.currentPlatform,
///       );
///       FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
/// 3. After auth, call `PushService(apiClient).registerToken(...)`.
/// 4. On logout, call `PushService(apiClient).unregisterToken(...)`.
///
/// Backend endpoints (already live):
/// - POST   /notifications/devices
/// - DELETE /notifications/devices
class PushService {
  final ApiClient _api;

  PushService(this._api);

  Future<void> registerToken(
    String token, {
    required String platform,
    String? deviceName,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/notifications/devices',
      data: {
        'device_token': token,
        'platform': platform,
        if (deviceName != null) 'device_name': deviceName,
      },
    );
  }

  Future<void> unregisterToken(String token) async {
    await _api.delete<Map<String, dynamic>>(
      '/notifications/devices?token=$token',
    );
  }
}

/// Returns the target route for a notification payload, or null.
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
