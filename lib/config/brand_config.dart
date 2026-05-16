// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Produced by `tool/apply_brand.dart` from `branding/<slug>/brand.json`.
// Regenerate with:  dart run tool/apply_brand.dart <slug>
//
// Active brand: default
import 'package:flutter/material.dart';

/// Build-time white-label brand configuration.
///
/// Holds the values baked into the binary: theme palette, launcher /
/// wordmark name, target backend, and the bundled logo asset. Runtime
/// per-society branding (a society's own logo / name fetched from the
/// backend) is layered on top of this — see `BrandLogo`.
class BrandConfig {
  BrandConfig._();

  /// Brand folder under `branding/` this build was generated from.
  static const String slug = 'default';

  /// Launcher label + in-app wordmark fallback.
  static const String appName = 'Ezgate Admin';

  /// Backend instance this build targets.
  static const String apiBaseUrl = 'https://community.eassy.life';

  /// Bundled logo — shown on splash / login and as the runtime fallback
  /// when a society has no `logo_url`.
  static const String logoAsset = 'assets/branding/logo.png';

  // --- Brand palette (build-time). Status / neutral colours live in
  //     theme.dart and are not brand-variable. ---
  static const Color primaryColor = Color(0xFFFFA300);
  static const Color primaryColorVariant = Color(0xFFF5A623);
  static const Color primarySoftTint = Color(0xFFFFEDCC);
  static const Color brandSurfaceAccent = Color(0xFFFAEBDD);
  static const Color brandMutedText = Color(0xFF7A5828);
  static const Color secondaryColor = Color(0xFFF5A623);
}
