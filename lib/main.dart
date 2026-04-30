import 'dart:convert';
import 'package:community_admin/config/constants.dart';
import 'package:community_admin/config/router.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/core/notifications/action_dispatcher.dart';
import 'package:community_admin/core/notifications/categories.dart';
import 'package:community_admin/core/notifications/local_notifications_service.dart';
import 'package:community_admin/providers/auth_provider.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/services/api_client.dart';
import 'package:community_admin/services/auth_token_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Top-level background isolate handler.
///
/// Must be annotated `@pragma('vm:entry-point')` so the Flutter engine
/// can find it when the app is terminated. Decodes the FCM data payload
/// and re-displays it via `flutter_local_notifications` so the
/// system-tray notification carries our category-aware action buttons.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await LocalNotificationsService.instance.init(
      onForegroundResponse: _handleNotificationResponseForeground,
      onBackgroundResponse: _handleNotificationResponseBackground,
    );
    final data = Map<String, dynamic>.from(message.data);
    final notif = message.notification;
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
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[bgHandler] failed: $e\n$st');
    }
  }
}

/// Foreground tap response handler.
void _handleNotificationResponseForeground(NotificationResponse response) {
  _handleResponse(response, isBackground: false);
}

/// Background tap response handler. MUST be a top-level function so
/// the engine can rehydrate it in the background isolate.
@pragma('vm:entry-point')
void _handleNotificationResponseBackground(NotificationResponse response) {
  _handleResponse(response, isBackground: true);
}

/// Shared response handler. Decodes the JSON payload, runs the
/// dispatcher, and either:
///   - On a foreground action with a route → push it onto the global
///     tap stream so the active app navigates.
///   - On a silent (background-eligible) action → fire the API call
///     and dismiss the notification.
Future<void> _handleResponse(
  NotificationResponse response, {
  required bool isBackground,
}) async {
  final raw = response.payload;
  if (raw == null || raw.isEmpty) return;
  Map<String, dynamic> data;
  try {
    data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return;
  }

  final categoryId = resolveCategory(data);
  final actionId = response.actionId;

  // Plain tap (no action button) — route via the default route.
  if (actionId == null || actionId.isEmpty) {
    final route = routeForData(data);
    if (route != null) PushTapRoute.publish(route);
    return;
  }

  final reply = response.input;
  final result = await NotificationActionDispatcher.instance.dispatch(
    categoryId: categoryId,
    actionId: actionId,
    data: data,
    replyText: reply,
  );

  if (result.isForegroundRoute) {
    PushTapRoute.publish(result.route!);
  }
}

/// Cross-isolate broadcast for tap-driven navigation. The background
/// isolate publishes; the main isolate's PushService subscribes via
/// the existing `onTapRoute` stream.
class PushTapRoute {
  PushTapRoute._();
  static final _controller = ValueNotifier<String?>(null);
  static ValueListenable<String?> get listenable => _controller;

  static void publish(String route) {
    _controller.value = route;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // QA #57 — cookie-based refresh-token migration. Access token no
  // longer lives on disk; `communityos_refresh` cookie in
  // `PersistCookieJar` rehydrates the session via `POST /auth/refresh`
  // on launch. Awaiting `apiClient.init()` loads the jar and wires
  // the Dio interceptors before any provider fires a request.
  const storage = FlutterSecureStorage();
  String? bootTenantId;
  try {
    bootTenantId = await storage.read(key: AppConstants.tenantKey);
  } catch (_) {
    // Keystore occasionally locked at cold-boot time; fall through
    // with nulls and the user will see /login.
  }

  // Hive init for offline notification cache. Single box opens lazily
  // inside NotificationService; init here primes the document
  // directory so the first lookup is fast.
  try {
    await Hive.initFlutter();
  } catch (e, st) {
    if (kDebugMode) debugPrint('[hive] init failed: $e\n$st');
  }

  final apiClient = ApiClient();
  await apiClient.init();
  if (bootTenantId != null) {
    apiClient.updateTenantId(bootTenantId);
  }

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    // Local notifications plugin handles iOS categories + Android
    // channels; init here on the main isolate so the foreground push
    // listener can call show() without a re-init race.
    await LocalNotificationsService.instance.init(
      onForegroundResponse: _handleNotificationResponseForeground,
      onBackgroundResponse: _handleNotificationResponseBackground,
    );
  } catch (e, st) {
    if (kDebugMode) debugPrint('[firebase] init failed: $e\n$st');
  }

  runApp(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
    ],
    child: const CommunityAdminApp(),
  ));
}

class CommunityAdminApp extends ConsumerStatefulWidget {
  const CommunityAdminApp({super.key});

  @override
  ConsumerState<CommunityAdminApp> createState() =>
      _CommunityAdminAppState();
}

class _CommunityAdminAppState extends ConsumerState<CommunityAdminApp> {
  @override
  void initState() {
    super.initState();

    // Register the 401 handler. Guards against clearing state when the
    // user isn't authenticated (public OTP endpoints hit the same code
    // path if the backend returns 401 for an unregistered number).
    final apiClient = ref.read(apiClientProvider);
    apiClient.onUnauthorized = () {
      final auth = ref.read(authStateProvider);
      if (auth.isAuthenticated) {
        ref.read(authStateProvider.notifier).logout();
      }
    };

    _bootstrapPush();

    ref.listenManual<AuthState>(authStateProvider, (prev, next) async {
      if (prev?.isAuthenticated == true && next.isAuthenticated == false) {
        await ref.read(pushServiceProvider).unregisterBeforeLogout();
        NotificationActionDispatcher.instance
            .primeForegroundCredentials(token: null, tenantId: null);
      }
      if (prev?.isAuthenticated != true &&
          next.isAuthenticated == true &&
          _shouldRegisterPush(next)) {
        await ref
            .read(pushServiceProvider)
            .registerAfterLogin(deviceName: next.user?.name);
        await _subscribeTopicsFor(next);
      }
      // Society auto-select after OTP can race the login transition;
      // register once the tenant resolves.
      if (prev?.selectedTenantId == null &&
          next.selectedTenantId != null &&
          _shouldRegisterPush(next)) {
        await ref
            .read(pushServiceProvider)
            .registerAfterLogin(deviceName: next.user?.name);
        await _subscribeTopicsFor(next);
      }
      // Society switch — re-subscribe to the new tenant's topics.
      if (prev?.selectedTenantId != null &&
          next.selectedTenantId != null &&
          prev?.selectedTenantId != next.selectedTenantId) {
        final push = ref.read(pushServiceProvider);
        await push.unsubscribeFromAllTopics();
        await _subscribeTopicsFor(next);
      }
      // Keep the action dispatcher's foreground credentials current —
      // it falls back to secure storage in the background isolate but
      // foreground taps want the most recent in-memory token.
      NotificationActionDispatcher.instance.primeForegroundCredentials(
        token: AuthTokenStore.instance.accessToken,
        tenantId: next.selectedTenantId,
      );
    });
  }

  /// FCM device registration is gated: only real admins with a
  /// selected tenant should hit /notifications/devices. Super admins
  /// have no tenant scope and get 403 from the tenant interceptor.
  bool _shouldRegisterPush(AuthState s) {
    final user = s.user;
    if (user == null) return false;
    if (user.isSuperAdmin) return false;
    if (s.selectedTenantId == null) return false;
    return true;
  }

  /// Subscribe FCM topics for the current tenant + role. Admin's
  /// committee role uses underscore (`committee_member`) which
  /// `_sanitize` preserves.
  Future<void> _subscribeTopicsFor(AuthState s) async {
    final tenantId = s.selectedTenantId;
    if (tenantId == null) return;
    // Resolve the role from the selected society (preferred — it's
    // tenant-scoped) with `s.user.role` as a fallback for older
    // payloads that don't populate the per-society role field.
    final society =
        s.user?.societies.where((soc) => soc.id == tenantId).firstOrNull;
    final role = society?.role ?? s.user?.role;
    final push = ref.read(pushServiceProvider);
    await push.subscribeToTopics(
      tenantId: tenantId,
      role: role,
    );
  }

  Future<void> _bootstrapPush() async {
    final push = ref.read(pushServiceProvider);
    await push.init();

    push.onTapRoute.listen((route) {
      final router = ref.read(routerProvider);
      try {
        router.go(route);
      } catch (_) {}
    });

    // Bridge background-isolate tap-route publishes (from the local
    // notifications plugin's tap callback) into the same router.
    PushTapRoute.listenable.addListener(() {
      final route = PushTapRoute.listenable.value;
      if (route == null || route.isEmpty) return;
      final router = ref.read(routerProvider);
      try {
        router.go(route);
      } catch (_) {}
    });

    final auth = ref.read(authStateProvider);
    if (_shouldRegisterPush(auth)) {
      await push.registerAfterLogin(deviceName: auth.user?.name);
      await _subscribeTopicsFor(auth);
    }
    // Prime dispatcher credentials on cold-start when an auth state
    // already existed (refresh-cookie path repopulated the token).
    NotificationActionDispatcher.instance.primeForegroundCredentials(
      token: AuthTokenStore.instance.accessToken,
      tenantId: auth.selectedTenantId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ezegate Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
