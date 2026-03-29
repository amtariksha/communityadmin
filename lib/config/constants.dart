class AppConstants {
  static const String appName = 'CommunityOS Admin';
  static const String appVersion = '1.0.0';

  // API
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://community.eassy.life',
  );

  // Storage keys
  static const String tokenKey = 'communityos_admin_token';
  static const String tenantKey = 'communityos_admin_tenant';
  static const String userKey = 'communityos_admin_user';

  // Pagination
  static const int defaultPageSize = 20;
}
