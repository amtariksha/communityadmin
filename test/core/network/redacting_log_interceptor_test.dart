import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_admin/core/network/redacting_log_interceptor.dart';

/// Debug builds log requests; tokens, cookies, OTPs, phone numbers, e-mails
/// and signed links' query strings must never reach that log.
void main() {
  group('redaction', () {
    test('headers: Authorization, cookies and device keys are hidden', () {
      final headers = redactHeaders({
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1In0.c2lnbmF0dXJl',
        'cookie': 'communityos_refresh=abc',
        'x-device-key': 'k-123',
        'x-tenant-id': 'tenant-1',
      });
      expect(headers['Authorization'], redactedValue);
      expect(headers['cookie'], redactedValue);
      expect(headers['x-device-key'], redactedValue);
      expect(headers['x-tenant-id'], 'tenant-1');
    });

    test('bodies: tokens, OTPs, phones and e-mails at any depth', () {
      final logged = describeBody({
        'phone': '+910000000123',
        'otp': '482913',
        'data': {
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1In0.c2lnbmF0dXJl',
          'user': {'name': 'Asha Resident', 'email': 'asha@example.test'},
          'note': 'Call 9876543210 or +91 9876543210',
        },
        'items': [
          {'refresh_token': 'r-1', 'amount': 1200},
        ],
      });
      expect(logged, isNot(contains('482913')));
      expect(logged, isNot(contains('0000000123')));
      expect(logged, isNot(contains('eyJ')));
      expect(logged, isNot(contains('asha@example.test')));
      expect(logged, isNot(contains('9876543210')));
      expect(logged, isNot(contains('r-1')));
      expect(logged, contains('Asha Resident'));
      expect(logged, contains('1200'));
    });

    test('signed links lose their query string, in bodies and addresses', () {
      const signed = 'https://store.example.test/bucket/tenants/t/documents/f.pdf'
          '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=deadbeef';
      final logged = describeBody({'data': {'downloadUrl': signed}});
      expect(logged, contains('tenants/t/documents/f.pdf?<redacted>'));
      expect(logged, isNot(contains('deadbeef')));
      expect(redactUri(Uri.parse(signed)), endsWith('f.pdf?<redacted>'));
      expect(redactUri(Uri.parse('https://api.example.test/visitors?page=2&otp=1234')),
          'https://api.example.test/visitors?page=2&otp=<redacted>');
    });

    test('a JSON string body is redacted as JSON; form data shows no values', () {
      expect(describeBody('{"otp":"123456","purpose":"login"}'), '{"otp":"<redacted>","purpose":"login"}');
      final form = FormData.fromMap({'policy': 'p-secret', 'x-amz-signature': 's'});
      final logged = describeBody(form);
      expect(logged, isNot(contains('p-secret')));
      expect(logged, contains('files: 0'));
    });
  });

  test('the interceptor logs requests and responses through the redaction', () async {
    final lines = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _EchoAdapter();
    dio.interceptors.add(RedactingLogInterceptor(log: lines.add));
    await dio.post<dynamic>('/auth/verify-otp',
        data: {'phone': '+910000000123', 'otp': '482913'},
        options: Options(headers: {'Authorization': 'Bearer secret-token'}));
    final log = lines.join('\n');
    expect(log, contains('POST https://api.example.test/auth/verify-otp'));
    expect(log, isNot(contains('482913')));
    expect(log, isNot(contains('secret-token')));
    expect(log, isNot(contains('0000000123')));
    expect(log, isNot(contains('eyJ')));
  });
}

/// Answers every request with a token-bearing body, as /auth/verify-otp does.
class _EchoAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      '{"access_token":"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1In0.c2lnbmF0dXJl","user":{"phone":"+910000000123"}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
