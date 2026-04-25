class AppConstants {
  static const String appName = 'ezegate Admin';
  static const String appVersion = '1.0.0';

  // API
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://community.eassy.life',
  );

  // Storage keys
  static const String tokenKey = 'ezegate_admin_token';
  static const String tenantKey = 'ezegate_admin_tenant';
  static const String userKey = 'ezegate_admin_user';

  // Pagination
  static const int defaultPageSize = 20;
}
