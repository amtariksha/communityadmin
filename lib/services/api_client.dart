import 'package:community_admin/config/constants.dart';
import 'package:community_admin/services/auth_token_store.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Single-instance HTTP client for the admin-mobile app.
///
/// QA #57 cookie-auth migration — mirrors the resident + guard apps.
/// The refresh token lives in an httpOnly cookie persisted by
/// `PersistCookieJar`; the 15-minute access token lives only in
/// [AuthTokenStore]. On 401 from a protected endpoint the auth
/// interceptor calls `/auth/refresh` with an empty body, stores the
/// new access token, and retries the original request once.
///
/// Must call [init] from `main()` before `runApp` so the cookie jar
/// has rehydrated from disk by the time the first provider fires.
class ApiClient {
  late final Dio _dio;
  late final PersistCookieJar _cookieJar;
  bool _initialised = false;

  String? _tenantId;

  /// Invoked when both access-token refresh AND the cookie have been
  /// rejected.
  void Function()? onUnauthorized;

  void Function(String newAccessToken)? onRefreshed;

  Future<bool>? _pendingRefresh;

  bool get hasCredentials => AuthTokenStore.instance.accessToken != null;

  PersistCookieJar get cookieJar => _cookieJar;

  void updateTenantId(String? tenantId) {
    _tenantId = tenantId;
    // Mirror to secure storage so the FCM background isolate can
    // attach `x-tenant-id` to silent action POSTs without reaching
    // into the live ApiClient instance.
    AuthTokenStore.instance.persistTenantForBackgroundIsolate(tenantId);
  }

  /// Back-compat shim — `token` forwards to [AuthTokenStore].
  void setCredentials(String? token, String? tenantId) {
    if (token != null && token.isNotEmpty) {
      AuthTokenStore.instance.setAccessToken(token);
    } else {
      AuthTokenStore.instance.clear();
    }
    _tenantId = tenantId;
    AuthTokenStore.instance.persistTenantForBackgroundIsolate(tenantId);
  }

  void clearCredentials() {
    AuthTokenStore.instance.clear();
    _tenantId = null;
    AuthTokenStore.instance.persistTenantForBackgroundIsolate(null);
  }

  Future<void> init() async {
    if (_initialised) return;
    final appDocDir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${appDocDir.path}/.ezegate_admin_cookies'),
    );

    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(CookieManager(_cookieJar));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = AuthTokenStore.instance.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (_tenantId != null) {
          options.headers['x-tenant-id'] = _tenantId!;
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        final isAuthPath = path.contains('/auth/');
        final alreadyRetried = error.requestOptions.extra['__refreshed'] == true;

        if (error.response?.statusCode == 401 &&
            !isAuthPath &&
            !alreadyRetried) {
          final refreshed = await _refreshWithCookie();
          if (refreshed) {
            final retryOptions = error.requestOptions
              ..extra['__refreshed'] = true
              ..headers['Authorization'] =
                  'Bearer ${AuthTokenStore.instance.accessToken ?? ''}';
            try {
              final retry = await _dio.fetch<dynamic>(retryOptions);
              return handler.resolve(retry);
            } catch (_) {
              // fall through
            }
          }
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
      );
    }

    _initialised = true;
  }

  Future<bool> _refreshWithCookie() {
    final existing = _pendingRefresh;
    if (existing != null) return existing;
    final future = _doRefresh();
    _pendingRefresh = future;
    future.whenComplete(() => _pendingRefresh = null);
    return future;
  }

  Future<bool> _doRefresh() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{},
      );
      final body = res.data;
      if (body == null) return false;
      final newToken = body['access_token'] as String?;
      if (newToken == null || newToken.isEmpty) return false;
      AuthTokenStore.instance.setAccessToken(newToken);
      onRefreshed?.call(newToken);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> refresh() => _refreshWithCookie();

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}
