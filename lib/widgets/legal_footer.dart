import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:community_admin/config/theme.dart';

/// Tappable "By continuing, you agree to our Terms and Privacy
/// Policy" footer used on the Login + OTP screens.
///
/// Routes via go_router's `context.push` to `/legal/terms` and
/// `/legal/privacy` — both routes are top-level (outside the auth
/// gate) so this works pre-login.
///
/// QA Round 14 #14-5c.
class LegalFooter extends StatefulWidget {
  const LegalFooter({super.key});

  @override
  State<LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<LegalFooter> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/terms');
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/privacy');
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.inter(
      fontSize: 12,
      color: AppTheme.textSecondary,
      height: 1.4,
    );
    final link = base.copyWith(
      color: AppTheme.primaryColor,
      fontWeight: FontWeight.w600,
    );
    return Center(
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            TextSpan(
              text: 'Terms',
              style: link,
              recognizer: _termsTap,
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: link,
              recognizer: _privacyTap,
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
