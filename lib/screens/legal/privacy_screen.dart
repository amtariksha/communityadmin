import 'package:community_admin/screens/legal/legal_screen.dart';
import 'package:community_admin/services/cms_service.dart';
import 'package:flutter/material.dart';

/// Privacy Policy — fetches `app=admin&type=privacy_policy`, falls
/// back to `assets/legal/admin_privacy.md`.
/// QA Round 14 #14-5c.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'Privacy Policy',
      cmsPageType: CmsService.typePrivacy,
      fallbackAssetPath: 'assets/legal/admin_privacy.md',
    );
  }
}
