import 'package:community_admin/config/brand_config.dart';

class AppConstants {
  /// User-facing brand name — resolved from the active white-label
  /// brand (`tool/apply_brand.dart`).
  static const String appName = BrandConfig.appName;
  static const String appVersion = '1.0.0';

  // API — defaults to the brand's target backend; an explicit
  // --dart-define=API_BASE_URL still wins for ad-hoc builds.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: BrandConfig.apiBaseUrl,
  );

  // Storage keys
  static const String tokenKey = 'meraghar_admin_token';
  static const String tenantKey = 'meraghar_admin_tenant';
  static const String userKey = 'meraghar_admin_user';

  // Pagination
  static const int defaultPageSize = 20;
}
