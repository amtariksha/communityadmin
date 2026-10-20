import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug builds' request log, with the secrets taken out.
///
/// Logs each request's method, address, headers and body and each response's
/// status and body, but never an access token, cookie, device key, OTP,
/// password, phone number, e-mail or a signed link's query string (which is
/// the credential that opens a stored file). Attach it only under
/// `kDebugMode`: a release build never carries it.
class RedactingLogInterceptor extends Interceptor {
  RedactingLogInterceptor({void Function(String line)? log})
      : _log = log ?? ((line) => debugPrint(line));

  final void Function(String line) _log;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log('--> ${options.method} ${redactUri(options.uri)}');
    _log('    headers: ${jsonEncode(redactHeaders(options.headers))}');
    if (options.data != null) _log('    body: ${describeBody(options.data)}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final request = response.requestOptions;
    _log('<-- ${response.statusCode} ${request.method} ${redactUri(request.uri)}');
    if (response.data != null) _log('    body: ${describeBody(response.data)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    _log('<-- ${err.response?.statusCode ?? '---'} ${request.method} '
        '${redactUri(request.uri)} (${err.type.name})');
    final data = err.response?.data;
    if (data != null) _log('    body: ${describeBody(data)}');
    handler.next(err);
  }
}

const String redactedValue = '<redacted>';
const int _maxLoggedChars = 4000;

/// Key fragments (lower case, letters and digits only) whose values are never logged.
const List<String> _sensitiveKeyParts = [
  'token',
  'authorization',
  'cookie',
  'otp',
  'password',
  'passcode',
  'secret',
  'signature',
  'credential',
  'apikey',
  'devicekey',
  'phone',
  'mobile',
  'email',
];

/// Whether a header, field or query key names a value that must not be logged.
bool isSensitiveKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (normalized == 'pin' || normalized.endsWith('mpin') || normalized == 'upipin') return true;
  return _sensitiveKeyParts.any(normalized.contains);
}

/// Headers with every sensitive value replaced.
Map<String, Object?> redactHeaders(Map<String, dynamic> headers) => {
      for (final entry in headers.entries)
        entry.key: isSensitiveKey(entry.key) ? redactedValue : redactText('${entry.value}'),
    };

/// Query parameters that sign a stored-file link: the whole query goes.
final RegExp _signedLinkParam = RegExp(
  r'^(x-amz-|x-goog-)|^(signature|expires|policy|key-pair-id|sig|se|sp|sv)$',
  caseSensitive: false,
);

/// The request's address with sensitive (or signing) query values taken out.
String redactUri(Uri uri) {
  final path = redactText(uri.replace(query: '').toString().replaceFirst(RegExp(r'\?$'), ''));
  if (!uri.hasQuery) return path;
  final params = uri.queryParametersAll;
  if (params.keys.any(_signedLinkParam.hasMatch)) return '$path?$redactedValue';
  final query = [
    for (final entry in params.entries)
      for (final value in entry.value)
        '${entry.key}=${isSensitiveKey(entry.key) ? redactedValue : redactText(value)}',
  ].join('&');
  return '$path?$query';
}

final RegExp _linkQuery = RegExp(r'''(https?://[^\s?"'<>]+)\?[^\s"'<>]*''');
final RegExp _jwt = RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+');
final RegExp _indianPhone = RegExp(r'(?<![\w+])(?:\+91[\s-]?\d{10}|[6-9]\d{9})(?!\w)');
final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');

/// Free text with links' query strings, tokens, phone numbers and e-mails taken out.
String redactText(String text) => text
    .replaceAllMapped(_linkQuery, (match) => '${match.group(1)}?$redactedValue')
    .replaceAll(_jwt, redactedValue)
    .replaceAll(_indianPhone, '<phone>')
    .replaceAll(_email, '<email>');

/// A body as logged: sensitive fields replaced, files and form fields not shown, cut at 4000 characters.
String describeBody(Object? data) {
  final String text;
  if (data is FormData) {
    text = 'FormData(fields: ${data.fields.map((field) => field.key).join(', ')}; '
        'files: ${data.files.length})';
  } else if (data is Map || data is List) {
    text = jsonEncode(redactValue(data));
  } else if (data is String) {
    text = _redactJsonText(data);
  } else {
    text = redactText('$data');
  }
  return text.length > _maxLoggedChars ? '${text.substring(0, _maxLoggedChars)}…' : text;
}

/// A decoded JSON value with sensitive fields replaced, at any depth.
Object? redactValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': isSensitiveKey('${entry.key}') ? redactedValue : redactValue(entry.value),
    };
  }
  if (value is List) return [for (final item in value) redactValue(item)];
  if (value is String) return redactText(value);
  return value;
}

String _redactJsonText(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      return jsonEncode(redactValue(jsonDecode(text)));
    } on FormatException {
      // Not JSON after all: logged as free text below.
    }
  }
  return redactText(text);
}
