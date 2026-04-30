import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory store for the short-lived (15-minute) access token on
/// the admin-mobile app.
///
/// Per QA #57 the refresh token lives in an httpOnly cookie persisted
/// by `PersistCookieJar`; the access token itself does not touch disk
/// in normal foreground use — if the app is killed and reopened
/// without the cookie present the admin simply re-auths.
///
/// **Background-isolate exception (notifications-flutter-admin.md):**
/// The FCM background isolate has no `AuthTokenStore` instance, so
/// silent notification actions (e.g. Acknowledge a committee
/// escalation, Approve / Reject a tenant onboarding) cannot read the
/// in-memory token. To support tap-to-act UX we mirror the access
/// token + active tenant id to `flutter_secure_storage` under
/// dispatcher-only keys ([bgAccessTokenKey] / [bgTenantIdKey]). The
/// 15-min TTL is preserved (the server still rejects expired tokens),
/// and the mirror is cleared on logout. The dispatcher reads these
/// keys when its in-memory primed credentials are not set.
class AuthTokenStore {
  AuthTokenStore._();
  static final instance = AuthTokenStore._();

  /// Secure-storage key for the dispatcher's background-isolate
  /// access token mirror. Distinct from [AppConstants.tokenKey] (which
  /// is no longer used for storage) so an audit can grep this single
  /// constant to find the dispatcher footprint.
  static const String bgAccessTokenKey = 'admin_bg_access_token';
  static const String bgTenantIdKey = 'admin_bg_tenant_id';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  String? _accessToken;

  String? get accessToken => _accessToken;

  void setAccessToken(String token) {
    _accessToken = token;
    // Best-effort mirror — never crash auth flow if secure storage is
    // briefly locked at boot or fails to write.
    persistForBackgroundIsolate(token: token).catchError((Object e) {
      if (kDebugMode) debugPrint('[authStore] mirror write failed: $e');
    });
  }

  void clear() {
    _accessToken = null;
    persistForBackgroundIsolate(token: null).catchError((Object e) {
      if (kDebugMode) debugPrint('[authStore] mirror clear failed: $e');
    });
  }

  /// Mirror the current access token + tenant id to secure storage so
  /// the FCM background isolate can read them when dispatching silent
  /// actions. Pass `token: null` to clear the mirror (logout path).
  ///
  /// Tenant id mirror is independent — call without `tenantId` to
  /// preserve the existing value (e.g. when only the token rotates on
  /// refresh).
  Future<void> persistForBackgroundIsolate({
    String? token,
    String? tenantId,
    bool updateTenant = false,
  }) async {
    try {
      if (token == null) {
        await _storage.delete(key: bgAccessTokenKey);
      } else {
        await _storage.write(key: bgAccessTokenKey, value: token);
      }
      if (updateTenant) {
        if (tenantId == null) {
          await _storage.delete(key: bgTenantIdKey);
        } else {
          await _storage.write(key: bgTenantIdKey, value: tenantId);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[authStore] persist failed: $e');
    }
  }

  /// Convenience for the auth listener — sync the tenant mirror after
  /// society select / switch. Token is left untouched.
  Future<void> persistTenantForBackgroundIsolate(String? tenantId) {
    return persistForBackgroundIsolate(
      token: _accessToken,
      tenantId: tenantId,
      updateTenant: true,
    );
  }
}
