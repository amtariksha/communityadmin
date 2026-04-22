import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:community_admin/config/constants.dart';

/// Single-instance HTTP client for the admin app.
///
/// Matches the resident and guard apps: Authorization / tenant
/// headers are attached synchronously from in-memory state set by
/// [setCredentials]. The previous implementation read secure storage
/// on every request AND called `_storage.deleteAll()` on ANY 401,
/// which silently logged the admin out whenever the backend hiccuped
/// — explaining tester item #170 "cannot log in at all".
class ApiClient {
  late final Dio _dio;
  String? _token;
  String? _tenantId;

  /// Invoked when a request comes back with 401. The root widget
  /// registers a handler that logs the user out and routes to /login.
  void Function()? onUnauthorized;

  bool get hasCredentials => _token != null;

  /// Called by AuthNotifier on login, session restore, and main()
  /// bootstrap. Idempotent.
  void setCredentials(String? token, String? tenantId) {
    _token = token;
    _tenantId = tenantId;
  }

  void updateTenantId(String? tenantId) {
    _tenantId = tenantId;
  }

  void clearCredentials() {
    _token = null;
    _tenantId = null;
  }

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Synchronous in-memory read — no race conditions, no storage delays.
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        if (_tenantId != null) {
          options.headers['x-tenant-id'] = _tenantId!;
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Auto-logout on 401 via callback. Do NOT wipe storage here —
        // the callback guards against clearing state when the user
        // isn't yet authenticated (public OTP endpoints).
        if (error.response?.statusCode == 401) {
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
  }

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
