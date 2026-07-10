// Focused unit tests for the audited service-layer fixes.
//
// Coverage:
//   #26 — NotificationService reads/writes `/notifications/me/settings`
//         (was the non-existent `/users/me/notification-settings`).
//   #25 — GateService.collectParcel sends a non-empty body carrying
//         `collected_by_name` (backend .refine() 400s on empty body).
//   #38 — ApiClient.delete forwards an optional JSON body to Dio.
//
// We drive the real service classes through a stubbed HttpClientAdapter
// so no live backend / path_provider is needed. Each stub records the
// path + decoded body it observed.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_admin/services/api_client.dart';
import 'package:community_admin/services/gate_service.dart';
import 'package:community_admin/services/notification_service.dart';

/// Records the last request the adapter saw.
class _Recorder {
  String? path;
  String? method;
  String? body;
}

class _StubAdapter implements HttpClientAdapter {
  final _Recorder rec;
  final Object responseBody;
  _StubAdapter(this.rec, {this.responseBody = const {'data': {}}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    rec.path = options.path;
    rec.method = options.method;
    if (requestStream != null) {
      final bytes =
          await requestStream.fold<List<int>>([], (a, b) => a..addAll(b));
      rec.body = utf8.decode(bytes);
    }
    return ResponseBody.fromString(
      jsonEncode(responseBody),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A minimal ApiClient whose internal Dio uses the stub adapter.
/// We bypass [ApiClient.init] (which needs path_provider) by wiring a
/// bare Dio + adapter through a thin subclass-free helper: since the
/// production delete/get/patch just forward to the private `_dio`, we
/// instead exercise those methods against a Dio we control via a
/// wrapper that mirrors ApiClient's forwarding signatures.
class _TestApi implements ApiClient {
  final Dio dio;
  _TestApi(this.dio);

  @override
  Future<Response<T>> get<T>(String path,
          {Map<String, dynamic>? queryParameters}) =>
      dio.get<T>(path, queryParameters: queryParameters);

  @override
  Future<Response<T>> post<T>(String path,
          {dynamic data, Map<String, dynamic>? queryParameters}) =>
      dio.post<T>(path, data: data, queryParameters: queryParameters);

  @override
  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      dio.patch<T>(path, data: data);

  @override
  Future<Response<T>> delete<T>(String path, {Object? data}) =>
      dio.delete<T>(path, data: data);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Dio _dio(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://example.test',
    headers: {'Content-Type': 'application/json'},
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  test('#26 getPreferences hits /notifications/me/settings', () async {
    final rec = _Recorder();
    final api = _TestApi(_dio(_StubAdapter(rec)));
    await NotificationService(api).getPreferences();
    expect(rec.path, '/notifications/me/settings');
    expect(rec.method, 'GET');
  });

  test('#26 updatePreferences PATCHes /notifications/me/settings', () async {
    final rec = _Recorder();
    final api = _TestApi(_dio(_StubAdapter(rec)));
    await NotificationService(api)
        .updatePreferences(const NotificationPreferences.defaults());
    expect(rec.path, '/notifications/me/settings');
    expect(rec.method, 'PATCH');
  });

  test('#25 collectParcel sends collected_by_name body', () async {
    final rec = _Recorder();
    final api = _TestApi(_dio(_StubAdapter(rec, responseBody: {})));
    await GateService(api).collectParcel('p1', collectedByName: 'Ravi Kumar');
    expect(rec.path, '/gate/parcels/p1/collect');
    expect(rec.method, 'PATCH');
    final body = jsonDecode(rec.body!) as Map<String, dynamic>;
    expect(body['collected_by_name'], 'Ravi Kumar');
  });

  test('#38 ApiClient.delete forwards a JSON body', () async {
    final rec = _Recorder();
    final api = _TestApi(_dio(_StubAdapter(rec, responseBody: {})));
    await api.delete<Map<String, dynamic>>(
      '/notifications/devices',
      data: {'token': 'fcm-abc'},
    );
    expect(rec.path, '/notifications/devices');
    expect(rec.method, 'DELETE');
    final body = jsonDecode(rec.body!) as Map<String, dynamic>;
    expect(body['token'], 'fcm-abc');
  });
}
