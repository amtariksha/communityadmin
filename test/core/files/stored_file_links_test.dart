// StoredFileLinks — signed links for files in the private bucket, with the
// fallback rules: signed → use it; 404 file_not_found → unavailable; 400
// file_url_not_ours, any other failure or offline → the raw URL; non-http
// values never reach the server; links cached until 5 min before expiry.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_admin/core/files/stored_file_links.dart';
import 'package:community_admin/core/files/stored_file_links_provider.dart';
import 'package:community_admin/core/files/stored_image.dart';
import 'package:community_admin/services/api_client.dart';

const _raw = 'https://bucket.example.test/store/tenants/t-1/photo.jpg';
const _signed =
    'https://bucket.example.test/store/tenants/t-1/photo.jpg?sig=abc';

/// Answers `POST /upload/download-url` like the API would, without a socket.
class _StubAdapter implements HttpClientAdapter {
  int status = 201;
  Object? body = {
    'data': {'downloadUrl': _signed},
  };
  bool offline = false;
  Completer<void>? gate;
  final List<Map<String, dynamic>> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final sent = await utf8.decodeStream(requestStream!);
    requests.add({
      'path': options.path,
      ...jsonDecode(sent) as Map<String, dynamic>,
    });
    if (gate != null) await gate!.future;
    if (offline) throw const SocketException('offline');
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Api extends ApiClient {
  final Dio _http;
  _Api(_StubAdapter adapter)
    : _http = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) => _http.post<T>(path, data: data, queryParameters: queryParameters);
}

void main() {
  late _StubAdapter server;
  late DateTime now;
  late StoredFileLinks links;

  setUp(() {
    server = _StubAdapter();
    now = DateTime.utc(2026, 10, 20, 9);
    links = StoredFileLinks(_Api(server), clock: () => now);
  });

  test('a stored file resolves to its signed link', () async {
    expect(await links.resolve(_raw), _signed);
    expect(server.requests.single, {
      'path': '/upload/download-url',
      'file_url': _raw,
      'disposition': 'inline',
    });
  });

  test('opening sends the disposition and the file name', () async {
    await links.resolve(
      _raw,
      disposition: StoredFileDisposition.attachment,
      fileName: 'report.pdf',
    );
    expect(server.requests.single['disposition'], 'attachment');
    expect(server.requests.single['file_name'], 'report.pdf');
  });

  test('404 file_not_found is unavailable', () async {
    server
      ..status = 404
      ..body = {
        'statusCode': 404,
        'message': 'File not found',
        'code': 'file_not_found',
      };
    expect(await links.resolve(_raw), isNull);
    expect(await links.resolve(_raw), isNull);
    expect(server.requests, hasLength(1));
  });

  test('400 file_url_not_ours uses the raw URL', () async {
    server
      ..status = 400
      ..body = {'statusCode': 400, 'code': 'file_url_not_ours'};
    expect(await links.resolve(_raw), _raw);
  });

  test('an older API (404 or 403 without a code) uses the raw URL', () async {
    server
      ..status = 404
      ..body = {
        'statusCode': 404,
        'message': 'Cannot POST /upload/download-url',
      };
    expect(await links.resolve(_raw), _raw);

    final other = StoredFileLinks(_Api(server..status = 403), clock: () => now);
    expect(await other.resolve(_raw), _raw);
  });

  test('a server error or a malformed body uses the raw URL', () async {
    server
      ..status = 500
      ..body = {'statusCode': 500};
    expect(await links.resolve(_raw), _raw);

    server
      ..status = 201
      ..body = {'data': <String, dynamic>{}};
    final other = StoredFileLinks(_Api(server), clock: () => now);
    expect(await other.resolve(_raw), _raw);
  });

  test('offline uses the raw URL', () async {
    server.offline = true;
    expect(await links.resolve(_raw), _raw);
  });

  test('values that are not http(s) URLs never reach the server', () async {
    expect(await links.resolve(null), isNull);
    expect(await links.resolve('  '), isNull);
    for (final value in [
      'data:image/png;base64,iVBORw0KGgo=',
      'file:///data/user/0/photo.jpg',
      'assets/images/logo.png',
      '/logo.png',
    ]) {
      expect(await links.resolve(value), value);
    }
    expect(server.requests, isEmpty);
  });

  test('a cached link is served without another request', () async {
    await links.resolve(_raw);
    expect(await links.resolve(_raw), _signed);
    expect(server.requests, hasLength(1));
  });

  test('concurrent requests for one file share one call', () async {
    server.gate = Completer<void>();
    final first = links.resolve(_raw);
    final second = links.resolve(_raw);
    server.gate!.complete();
    expect(await Future.wait([first, second]), [_signed, _signed]);
    expect(server.requests, hasLength(1));
  });

  test('a link is fetched again 5 minutes before it expires', () async {
    server.body = {
      'data': {
        'downloadUrl': _signed,
        'expiresAt': now.add(const Duration(minutes: 60)).toIso8601String(),
      },
    };
    await links.resolve(_raw);
    now = now.add(const Duration(minutes: 54));
    await links.resolve(_raw);
    expect(server.requests, hasLength(1));

    now = now.add(const Duration(minutes: 2));
    await links.resolve(_raw);
    expect(server.requests, hasLength(2));
  });

  test('without expiresAt a link is kept 45 minutes', () async {
    await links.resolve(_raw);
    now = now.add(const Duration(minutes: 44));
    await links.resolve(_raw);
    expect(server.requests, hasLength(1));

    now = now.add(const Duration(minutes: 2));
    await links.resolve(_raw);
    expect(server.requests, hasLength(2));
  });

  test('a fallback after a failure is retried soon', () async {
    server.offline = true;
    expect(await links.resolve(_raw), _raw);
    server.offline = false;
    now = now.add(const Duration(minutes: 2));
    expect(await links.resolve(_raw), _signed);
  });

  group('StoredAvatar', () {
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      ProviderScope(
        overrides: [storedFileLinksProvider.overrideWithValue(links)],
        child: const MaterialApp(
          home: Scaffold(
            body: StoredAvatar(url: _raw, fallback: Icon(Icons.person)),
          ),
        ),
      ),
    );

    testWidgets('loads the signed link', (tester) async {
      await tester.runAsync(() async {
        await pump(tester);
        await links.resolve(_raw);
      });
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, _signed);
    });

    testWidgets('shows the fallback when the file is not available', (
      tester,
    ) async {
      server
        ..status = 404
        ..body = {'code': 'file_not_found'};
      await tester.runAsync(() async {
        await pump(tester);
        await links.resolve(_raw);
      });
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
