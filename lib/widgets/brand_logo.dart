import 'package:flutter/material.dart';
import 'package:community_admin/config/brand_config.dart';
import 'package:community_admin/core/files/stored_image.dart';

/// Shows the logged-in society's runtime logo (`logo_url`, set by the
/// super admin — backend migration 099) when available, falling back
/// to the build-time bundled brand logo otherwise (also while the logo's
/// signed link resolves, or when it is not available).
///
/// Used wherever the admin app surfaces "the society's logo" — the
/// dashboard app bar most notably.
class BrandLogo extends StatelessWidget {
  /// The active society's `logo_url`. Null / empty → bundled fallback.
  final String? logoUrl;

  /// Rendered square edge length.
  final double size;

  const BrandLogo({super.key, this.logoUrl, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      BrandConfig.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    return StoredNetworkImage(
      url: logoUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (_) => fallback,
    );
  }
}
