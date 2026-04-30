import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:community_admin/config/constants.dart';
import 'package:community_admin/core/notifications/categories.dart';
import 'package:community_admin/services/auth_token_store.dart';
import 'package:uuid/uuid.dart';

/// Result of an action dispatch. The notification UI uses
/// [ActionResultStatus.failure] to re-display the notification with
/// a "Retry" affordance instead of silently swallowing the error.
enum ActionResultStatus { success, failure, cancelled, biometricFailed }

class ActionDispatchResult {
  final ActionResultStatus status;
  final String? message;

  /// `true` when the caller should launch / route the host app to the
  /// foreground so the user can complete the action (e.g. Assign,
  /// Download — flows that need full UI).
  final bool foreground;

  /// Route to push when [foreground] is true.
  final String? route;

  const ActionDispatchResult({
    required this.status,
    this.message,
    this.foreground = false,
    this.route,
  });

  bool get isSuccess => status == ActionResultStatus.success;
  bool get isForegroundRoute => foreground && route != null;
}

/// Dispatches notification actions to the backend.
///
/// Designed to work in **both** the main isolate (foreground tap) and
/// the background isolate (data-only push handler). Background-safe
/// because it never touches Riverpod / Flutter widget tree — uses
/// `flutter_secure_storage` for the access token and a fresh `Dio`
/// instance.
///
/// Per-category endpoint mapping (admin set):
///   - `committee_escalation:acknowledge` → `POST /notifications/:id/read`
///   - `approval_needed:approve|reject` → `POST /approvals/:id/{approve|reject}` (bio)
///   - `tenant_onboarding_pending:approve|reject` → `POST /units/members/:id/{approve|reject}` (bio)
///   - `ticket_escalation:assign` → foreground → `/tickets/:id?action=assign`
///   - `monthly_report:download|view` → foreground → `/notifications`
///   - All `view` actions → foreground → `routeForData`
///
/// Background-isolate auth strategy (decided per plan):
///   - AuthService mirrors the access token + tenant id to secure
///     storage on every refresh / login. This dispatcher reads those
///     keys when the in-memory primed credentials aren't set.
///   - On 401 we fail fast (no background cookie-refresh) and surface
///     "Session expired — open the app to sign in".
class NotificationActionDispatcher {
  NotificationActionDispatcher._();
  static final instance = NotificationActionDispatcher._();

  static const _storage = FlutterSecureStorage();
  static const _uuid = Uuid();

  /// Public entry. Returns a structured result.
  Future<ActionDispatchResult> dispatch({
    required String categoryId,
    required String actionId,
    required Map<String, dynamic> data,
    String? replyText,
  }) async {
    final descriptor = kAdminCategories[categoryId];
    if (descriptor == null) {
      return const ActionDispatchResult(
        status: ActionResultStatus.failure,
        message: 'Unknown category',
      );
    }
    final action = _findAction(descriptor.actions, actionId);
    if (action == null) {
      return const ActionDispatchResult(
        status: ActionResultStatus.failure,
        message: 'Unknown action',
      );
    }

    // Foreground actions are routed by the caller — we just compute
    // the route and let the caller push it.
    if (action.foreground) {
      final route = _foregroundRouteFor(categoryId, actionId, data);
      return ActionDispatchResult(
        status: ActionResultStatus.success,
        foreground: true,
        route: route,
      );
    }

    // Biometric gate for destructive silent actions.
    if (action.requiresBiometric) {
      final ok = await _authenticate(reason: 'Confirm "${action.label}"');
      if (!ok) {
        return const ActionDispatchResult(
          status: ActionResultStatus.biometricFailed,
          message: 'Biometric authentication failed',
        );
      }
    }

    return _dispatchSilent(
      categoryId: categoryId,
      actionId: actionId,
      data: data,
      replyText: replyText,
    );
  }

  // ---------------------------------------------------------------------------
  // Silent-action API call
  // ---------------------------------------------------------------------------

  Future<ActionDispatchResult> _dispatchSilent({
    required String categoryId,
    required String actionId,
    required Map<String, dynamic> data,
    String? replyText,
  }) async {
    final endpoint = _silentEndpointFor(categoryId, actionId, data);
    if (endpoint == null) {
      return const ActionDispatchResult(
        status: ActionResultStatus.failure,
        message: 'No endpoint mapped',
      );
    }

    final accessToken = await _readAccessToken();
    final tenantId = await _readTenantId();
    if (accessToken == null) {
      return const ActionDispatchResult(
        status: ActionResultStatus.failure,
        message: 'Not signed in',
      );
    }

    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        if (tenantId != null) 'x-tenant-id': tenantId,
        'Idempotency-Key': _uuid.v4(),
      },
    ));

    Future<Response<dynamic>> doPost() => dio.post<dynamic>(
          endpoint.path,
          data: endpoint.body(replyText),
        );

    try {
      await doPost();
      return const ActionDispatchResult(status: ActionResultStatus.success);
    } on DioException catch (e) {
      // Background isolate can't run the cookie-refresh interceptor —
      // fail fast on 401 so the notification re-displays with retry.
      if (e.response?.statusCode == 401) {
        return const ActionDispatchResult(
          status: ActionResultStatus.failure,
          message: 'Session expired — open the app to sign in',
        );
      }
      if (kDebugMode) {
        debugPrint('[actionDispatcher] $endpoint failed: ${e.message}');
      }
      return ActionDispatchResult(
        status: ActionResultStatus.failure,
        message: e.response?.statusMessage ?? 'Network error',
      );
    } catch (e) {
      return ActionDispatchResult(
        status: ActionResultStatus.failure,
        message: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Endpoint mapping
  // ---------------------------------------------------------------------------

  _Endpoint? _silentEndpointFor(
    String categoryId,
    String actionId,
    Map<String, dynamic> data,
  ) {
    final entityId = (data['entity_id'] ?? '').toString();
    final notificationId =
        (data['notification_id'] ?? data['inbox_id'] ?? '').toString();

    switch ('$categoryId:$actionId') {
      case 'committee_escalation:acknowledge':
        // Acknowledgement is just an inbox-mark-read; no entity
        // mutation. Backend marks the inbox row read.
        final id = notificationId.isNotEmpty ? notificationId : entityId;
        return _Endpoint(
          path: '/notifications/$id/read',
          body: (_) => <String, dynamic>{},
        );
      case 'approval_needed:approve':
        return _Endpoint(
          path: '/approvals/$entityId/approve',
          body: (_) => <String, dynamic>{},
        );
      case 'approval_needed:reject':
        return _Endpoint(
          path: '/approvals/$entityId/reject',
          body: (_) => <String, dynamic>{},
        );
      case 'tenant_onboarding_pending:approve':
        // Server contract per plan — verify with tenant-lifecycle module.
        return _Endpoint(
          path: '/units/members/$entityId/approve',
          body: (_) => <String, dynamic>{},
        );
      case 'tenant_onboarding_pending:reject':
        return _Endpoint(
          path: '/units/members/$entityId/reject',
          body: (_) => <String, dynamic>{},
        );
      default:
        return null;
    }
  }

  String? _foregroundRouteFor(
    String categoryId,
    String actionId,
    Map<String, dynamic> data,
  ) {
    final entityId = (data['entity_id'] ?? '').toString();
    switch ('$categoryId:$actionId') {
      case 'ticket_escalation:assign':
        return entityId.isNotEmpty
            ? '/tickets/$entityId?action=assign'
            : '/tickets';
      case 'monthly_report:download':
      case 'monthly_report:view':
        return '/notifications';
      default:
        // For "view" or other foreground actions, fall back to the
        // category default.
        return routeForData(data);
    }
  }

  // ---------------------------------------------------------------------------
  // Auth — token + biometric
  // ---------------------------------------------------------------------------

  /// Reads the admin's access token. Foreground path uses primed
  /// credentials from the auth listener; background isolate falls back
  /// to the secure-storage mirror written by AuthService.
  Future<String?> _readAccessToken() async {
    if (_foregroundToken != null) return _foregroundToken;
    try {
      return await _storage.read(key: AuthTokenStore.bgAccessTokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readTenantId() async {
    if (_foregroundTenantId != null) return _foregroundTenantId;
    try {
      return await _storage.read(key: AuthTokenStore.bgTenantIdKey);
    } catch (_) {
      return null;
    }
  }

  String? _foregroundToken;
  String? _foregroundTenantId;

  /// Foreground listener calls this so background fall-through to
  /// secure storage isn't needed when the app is alive.
  void primeForegroundCredentials({String? token, String? tenantId}) {
    _foregroundToken = token;
    _foregroundTenantId = tenantId;
  }

  Future<bool> _authenticate({required String reason}) async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics ||
          await auth.isDeviceSupported();
      if (!canCheck) {
        // Device has no biometric / passcode — fail closed for
        // destructive actions. The user can still tap "View" and act
        // from inside the app.
        return false;
      }
      return await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[actionDispatcher] biometric err: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  NotificationAction? _findAction(
    List<NotificationAction> actions,
    String id,
  ) {
    for (final a in actions) {
      if (a.id == id) return a;
    }
    return null;
  }
}

class _Endpoint {
  final String path;
  final dynamic Function(String? replyText) body;
  const _Endpoint({required this.path, required this.body});

  @override
  String toString() => path;
}
