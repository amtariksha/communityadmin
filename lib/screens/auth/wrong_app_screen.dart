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
/// §D5: "This app is for society administrators. Please use Eassy
/// Resident or Eassy Guard app." The Logout button calls
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
                child: const Icon(
                  Icons.no_accounts,
                  size: 40,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Wrong app for this account',
                style: AppTheme.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This app is for society administrators. Please use '
                'Eassy Resident or Eassy Guard app.',
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
}
