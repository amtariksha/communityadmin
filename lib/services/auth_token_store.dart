/// In-memory store for the short-lived (15-minute) access token on
/// the admin-mobile app.
///
/// Per QA #57 the refresh token lives in an httpOnly cookie persisted
/// by `PersistCookieJar`; the access token itself deliberately does
/// NOT touch disk — if the app is killed and reopened without the
/// cookie present the admin simply re-auths.
class AuthTokenStore {
  AuthTokenStore._();
  static final instance = AuthTokenStore._();

  String? _accessToken;

  String? get accessToken => _accessToken;

  void setAccessToken(String token) {
    _accessToken = token;
  }

  void clear() {
    _accessToken = null;
  }
}
