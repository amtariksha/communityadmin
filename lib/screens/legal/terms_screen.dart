import 'package:community_admin/screens/legal/legal_screen.dart';
import 'package:community_admin/services/cms_service.dart';
import 'package:flutter/material.dart';

/// Terms & Conditions — fetches `app=admin&type=terms_and_conditions`,
/// falls back to `assets/legal/admin_terms.md`.
/// QA Round 14 #14-5c.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'Terms & Conditions',
      cmsPageType: CmsService.typeTerms,
      fallbackAssetPath: 'assets/legal/admin_terms.md',
    );
  }
}
