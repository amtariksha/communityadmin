import 'package:community_admin/config/router.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/auth_provider.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // Firebase (project communityos-9a54d). Configs live in
  // android/app/google-services.json and ios/Runner/GoogleService-Info.plist.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (e, st) {
    if (kDebugMode) debugPrint('[firebase] init failed: $e\n$st');
  }

  runApp(const ProviderScope(child: CommunityAdminApp()));
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
      title: 'CommunityOS Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
