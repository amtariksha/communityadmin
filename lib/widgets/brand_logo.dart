import 'package:flutter/material.dart';
import 'package:community_admin/config/brand_config.dart';

/// Shows the logged-in society's runtime logo (`logo_url`, set by the
/// super admin — backend migration 099) when available, falling back
/// to the build-time bundled brand logo otherwise.
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

    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}
