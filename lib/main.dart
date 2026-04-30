import 'package:community_admin/config/constants.dart';
import 'package:community_admin/config/router.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/auth_provider.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/services/api_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal. The backend notification inbox keeps any
  // payload delivered while the app was terminated; tap routing runs
  // in the foreground PushService listeners.
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

  // Hive init for offline notification cache. Single box opens
  // lazily inside NotificationService; init here primes the document
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
      }
      if (prev?.isAuthenticated != true && next.isAuthenticated == true) {
        await ref
            .read(pushServiceProvider)
            .registerAfterLogin(deviceName: next.user?.name);
      }
    });
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

    final auth = ref.read(authStateProvider);
    if (auth.isAuthenticated) {
      await push.registerAfterLogin(deviceName: auth.user?.name);
    }
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
