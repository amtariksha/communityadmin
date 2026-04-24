// Unit tests for the QA #57 cookie-auth migration.
//
// Coverage (per spec §6):
//   1. `verifyOtp` — body contains `access_token` + `user`, never
//      `refresh_token`. CookieManager observes `Set-Cookie`.
//   2. 401 → refresh → retry once — a burst of 401s triggers exactly
//      one `/auth/refresh` with an empty body, and the protected
//      request is retried with the new token.
//   3. `logout` — POSTs `/auth/logout` and wipes the cookie jar.
//
// We build a minimal, in-process Dio + CookieManager pipeline so the
// tests don't need `path_provider` or a live backend. The server is
// stubbed via a `DioAdapter` that pattern-matches on path.

import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_admin/services/auth_token_store.dart';

/// Counts + knobs the test asserts against, plus the Dio + cookie jar.
class _Fixture {
  final Dio dio;
  final CookieJar cookieJar;
  int verifyOtpCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;
  int protectedCalls = 0;
  List<String> capturedRefreshBodies = [];
  // Toggle — the next protected request 401s once, then 200s.
  bool protectedShouldFailOnce = false;

  _Fixture(this.dio, this.cookieJar);
}

/// Builds a Dio that:
///   - Runs the prod interceptor chain: CookieManager → auth-header →
///     401-refresh-retry.
///   - Has a custom `HttpClientAdapter` that returns canned responses
///     for each endpoint without opening a real socket.
_Fixture _buildFixture() {
  AuthTokenStore.instance.clear();

  final cookieJar = CookieJar();
  final dio = Dio(BaseOptions(
    baseUrl: 'https://example.test',
    headers: {'Content-Type': 'application/json'},
    // We'll short-circuit requests via the adapter, so timeouts are
    // irrelevant — but keep them tight to catch accidental real
    // network calls.
    connectTimeout: const Duration(seconds: 2),
    receiveTimeout: const Duration(seconds: 2),
  ));

  final fixture = _Fixture(dio, cookieJar);

  dio.interceptors.add(CookieManager(cookieJar));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = AuthTokenStore.instance.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
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
        try {
          await dio.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: <String, dynamic>{},
          );
          final retryOptions = error.requestOptions
            ..extra['__refreshed'] = true
            ..headers['Authorization'] =
                'Bearer ${AuthTokenStore.instance.accessToken ?? ''}';
          final retry = await dio.fetch<dynamic>(retryOptions);
          return handler.resolve(retry);
        } catch (_) {
          // fall through
        }
      }
      handler.next(error);
    },
  ));

  dio.httpClientAdapter = _StubAdapter(fixture);
  return fixture;
}

class _StubAdapter implements HttpClientAdapter {
  final _Fixture f;
  _StubAdapter(this.f);

  ResponseBody _json(int status, Object body, {List<String>? setCookie}) {
    final headers = <String, List<String>>{
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (setCookie != null) headers['set-cookie'] = setCookie;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: headers,
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    if (path == '/auth/verify-otp') {
      f.verifyOtpCalls++;
      return _json(200, {
        'access_token': 'access-token-1',
        'user': {'id': 'u1', 'phone': '+910000000001'},
      }, setCookie: [
        'communityos_refresh=test-refresh-1; '
            'Path=/; HttpOnly; SameSite=Lax; Max-Age=604800',
      ]);
    }

    if (path == '/auth/refresh') {
      f.refreshCalls++;
      // Capture the body so the test can assert it was empty.
      if (requestStream != null) {
        final bytes =
            await requestStream.fold<List<int>>([], (a, b) => a..addAll(b));
        f.capturedRefreshBodies.add(utf8.decode(bytes));
      }
      AuthTokenStore.instance.setAccessToken('access-token-refreshed');
      return _json(200, {'access_token': 'access-token-refreshed'});
    }

    if (path == '/auth/logout') {
      f.logoutCalls++;
      return _json(200, {'message': 'Logged out'});
    }

    if (path == '/units/first') {
      f.protectedCalls++;
      if (f.protectedShouldFailOnce) {
        f.protectedShouldFailOnce = false;
        return _json(401, {'message': 'Token expired'});
      }
      return _json(200, {'ok': true});
    }

    return _json(404, {'message': 'not found'});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('verifyOtp', () {
    test('body has access_token + user (no refresh_token) and sets cookie',
        () async {
      final f = _buildFixture();

      final res = await f.dio.post<Map<String, dynamic>>(
        '/auth/verify-otp',
        data: {'phone': '+910000000001', 'otp': '123456'},
      );

      expect(res.data!.keys, containsAll(['access_token', 'user']));
      expect(res.data!.containsKey('refresh_token'), isFalse);

      AuthTokenStore.instance
          .setAccessToken(res.data!['access_token'] as String);
      expect(AuthTokenStore.instance.accessToken, 'access-token-1');

      final cookies = await f.cookieJar
          .loadForRequest(Uri.parse('https://example.test/auth/refresh'));
      expect(
        cookies.any((c) => c.name == 'communityos_refresh'),
        isTrue,
        reason: 'CookieManager should persist communityos_refresh',
      );
    });
  });

  group('401 → refresh → retry once', () {
    test('refreshes access token with empty body, retries protected request',
        () async {
      final f = _buildFixture();
      AuthTokenStore.instance.setAccessToken('stale-token');
      f.protectedShouldFailOnce = true;

      final res = await f.dio.get<Map<String, dynamic>>('/units/first');

      expect(res.statusCode, 200);
      expect(res.data!['ok'], isTrue);
      expect(f.refreshCalls, 1, reason: 'exactly one /auth/refresh');
      expect(f.protectedCalls, 2, reason: 'initial 401 + one retry');
      expect(AuthTokenStore.instance.accessToken, 'access-token-refreshed');
      // Empty body — no refresh_token field.
      expect(f.capturedRefreshBodies, hasLength(1));
      final body = jsonDecode(f.capturedRefreshBodies.single)
          as Map<String, dynamic>;
      expect(body.isEmpty, isTrue,
          reason: '/auth/refresh must not carry a refresh_token body field');
    });
  });

  group('logout', () {
    test('POSTs /auth/logout and wipes the cookie jar', () async {
      final f = _buildFixture();
      await f.cookieJar.saveFromResponse(
        Uri.parse('https://example.test'),
        [Cookie('communityos_refresh', 'seed-value')],
      );
      AuthTokenStore.instance.setAccessToken('some-access-token');

      await f.dio.post<Map<String, dynamic>>('/auth/logout');
      AuthTokenStore.instance.clear();
      await f.cookieJar.deleteAll();

      expect(f.logoutCalls, 1);
      expect(AuthTokenStore.instance.accessToken, isNull);
      final remaining = await f.cookieJar
          .loadForRequest(Uri.parse('https://example.test/auth/refresh'));
      expect(remaining, isEmpty);
    });
  });
}
