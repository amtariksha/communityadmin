import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/config/tokens.dart';
import 'package:community_admin/providers/auth_provider.dart';

/// Shown when a user successfully logs in but has zero
/// admin-allowlisted roles across all their societies (e.g. a
/// resident-only or guard-only account).
///
/// QA Round 14 #14-5b — copy lifted verbatim from the round-14 plan
/// §D5: "This app is for society administrators. Please use Mera Ghar
/// Resident or Mera Ghar Guard app." The Logout button calls
/// `authStateProvider.notifier.logout()` which clears creds and
/// flips state to unauthenticated; the router redirect chain then
/// pushes the user back to /login.
class WrongAppScreen extends ConsumerStatefulWidget {
  const WrongAppScreen({super.key});

  @override
  ConsumerState<WrongAppScreen> createState() => _WrongAppScreenState();
}

class _WrongAppScreenState extends ConsumerState<WrongAppScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await ref.read(authStateProvider.notifier).logout();
    } catch (_) {
      // logout swallows network errors; local state still clears.
    }
    if (mounted) setState(() => _loggingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final reason = ref.watch(
      authStateProvider.select((s) => s.wrongAppReason),
    );
    final copy = _copyFor(reason);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 72),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                ),
                child: Icon(
                  copy.icon,
                  size: 40,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                copy.heading,
                style: AppTheme.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                copy.body,
                style: AppTheme.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: _loggingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: Text(_loggingOut ? 'Signing out…' : 'Logout'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  _WrongAppCopy _copyFor(String? reason) {
    switch (reason) {
      case 'super_admin_use_web':
        return const _WrongAppCopy(
          icon: Icons.desktop_windows_outlined,
          heading: 'Use the admin web for super admin',
          body:
              'Super admin features (multi-society management, platform '
              'settings, legal documents) are available on the admin '
              'web. Open https://meraghar.amtariksha.com on a desktop browser '
              'to continue.',
        );
      case 'no_societies':
        return const _WrongAppCopy(
          icon: Icons.apartment_outlined,
          heading: 'No societies linked',
          body:
              'Your account is not linked to any society yet. Contact '
              'your community administrator or Mera Ghar support to be '
              'added before signing in to the admin app.',
        );
      case 'not_admin_role':
      default:
        return const _WrongAppCopy(
          icon: Icons.no_accounts,
          heading: 'Wrong app for this account',
          body:
              'This app is for society administrators. Please use '
              'Mera Ghar Resident or Mera Ghar Guard app.',
        );
    }
  }
}

class _WrongAppCopy {
  final IconData icon;
  final String heading;
  final String body;
  const _WrongAppCopy({
    required this.icon,
    required this.heading,
    required this.body,
  });
}
