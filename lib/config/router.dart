import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:community_admin/providers/auth_provider.dart';
import 'package:community_admin/screens/auth/login_screen.dart';
import 'package:community_admin/screens/auth/otp_screen.dart';
import 'package:community_admin/screens/auth/society_select_screen.dart';
import 'package:community_admin/screens/dashboard/dashboard_screen.dart';
import 'package:community_admin/screens/units/units_screen.dart';
import 'package:community_admin/screens/units/unit_detail_screen.dart';
import 'package:community_admin/screens/units/member_directory_screen.dart';
import 'package:community_admin/screens/finance/finance_screen.dart';
import 'package:community_admin/screens/gate/gate_screen.dart';
import 'package:community_admin/screens/more/more_screen.dart';
import 'package:community_admin/screens/tickets/tickets_screen.dart';
import 'package:community_admin/screens/tickets/ticket_detail_screen.dart';
import 'package:community_admin/screens/tickets/create_ticket_screen.dart';
import 'package:community_admin/screens/announcements/announcements_admin_screen.dart';
import 'package:community_admin/screens/announcements/create_announcement_screen.dart';
import 'package:community_admin/screens/staff/staff_list_screen.dart';
import 'package:community_admin/screens/staff/leave_approvals_screen.dart';
import 'package:community_admin/screens/staff/shifts_admin_screen.dart';
import 'package:community_admin/screens/approvals/approvals_admin_screen.dart';
import 'package:community_admin/widgets/app_shell.dart';

/// Listenable that only notifies when isAuthenticated changes
class _AuthChangeNotifier extends ChangeNotifier {
  bool _wasAuthenticated = false;

  void update(AuthState authState) {
    final isNowAuthenticated = authState.isAuthenticated;
    if (_wasAuthenticated != isNowAuthenticated) {
      _wasAuthenticated = isNowAuthenticated;
      notifyListeners();
    }
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier();

  ref.listen(authStateProvider, (prev, next) {
    authNotifier.update(next);
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/otp') ||
          state.matchedLocation.startsWith('/select-society');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        // If authenticated but no society selected and multiple societies
        if (authState.selectedTenantId == null &&
            authState.user != null &&
            authState.user!.societies.length > 1) {
          return '/select-society';
        }
        return '/';
      }
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/select-society',
        builder: (context, state) => const SocietySelectScreen(),
      ),

      // Main app shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/units',
            builder: (context, state) => const UnitsScreen(),
          ),
          GoRoute(
            path: '/units/:id',
            builder: (context, state) {
              final unitId = state.pathParameters['id']!;
              return UnitDetailScreen(unitId: unitId);
            },
          ),
          GoRoute(
            path: '/member-directory',
            builder: (context, state) => const MemberDirectoryScreen(),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceScreen(),
          ),
          GoRoute(
            path: '/gate',
            builder: (context, state) => const GateScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const MoreScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (context, state) => const TicketsScreen(),
          ),
          GoRoute(
            path: '/tickets/new',
            builder: (context, state) => const CreateTicketScreen(),
          ),
          GoRoute(
            path: '/tickets/:id',
            builder: (context, state) => TicketDetailScreen(
              ticketId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/announcements',
            builder: (context, state) => const AnnouncementsAdminScreen(),
          ),
          GoRoute(
            path: '/announcements/new',
            builder: (context, state) => const CreateAnnouncementScreen(),
          ),
          GoRoute(
            path: '/staff',
            builder: (context, state) => const StaffListScreen(),
          ),
          GoRoute(
            path: '/staff/leaves',
            builder: (context, state) => const LeaveApprovalsScreen(),
          ),
          GoRoute(
            path: '/staff/shifts',
            builder: (context, state) => const ShiftsAdminScreen(),
          ),
          GoRoute(
            path: '/approvals',
            builder: (context, state) => const ApprovalsAdminScreen(),
          ),
        ],
      ),
    ],
  );
});
