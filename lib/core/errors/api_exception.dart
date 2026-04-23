import 'package:dio/dio.dart';

import 'error_codes.dart';

/// Dart counterpart to admin-web's `ApiError`. Wraps Dio errors +
/// the server's `ApiErrorEnvelope` into a single typed exception
/// with human-friendly `userMessage`, per-field error map, and
/// optional stable `code`.
///
/// Usage:
///   try {
///     final res = await apiClient.post('/units', data: ...);
///   } on DioException catch (e) {
///     throw ApiException.fromDio(e);
///   }
///
/// Or in catch blocks:
///   catch (e) {
///     final apiErr = ApiException.from(e);
///     showSnackBar(apiErr.userMessage);
///     if (apiErr.fieldErrors['phone'] != null) {
///       // highlight phone field
///     }
///   }
class ApiException implements Exception {
  /// HTTP status from the server; null for offline / Dio-type errors.
  final int? status;

  /// Stable error code (e.g. `unit_number_exists`). Prefer over
  /// `userMessage` for branching — see `error_codes.dart`.
  final String? code;

  /// First message per rejected field, flattened from the server's
  /// `errors: {field: [msg]}` map. Empty when there's no Zod failure.
  final Map<String, String> fieldErrors;

  /// User-facing message. Priority: ERROR_CODES[code] → first field
  /// error → server `message` → friendly HTTP-status copy →
  /// network / timeout copy.
  final String userMessage;

  /// Rate-limit hint (429 only). Surface in the UI as a countdown.
  final int? retryAfterSeconds;

  /// Server request id for support / log correlation.
  final String? requestId;

  const ApiException({
    required this.userMessage,
    this.status,
    this.code,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
    this.requestId,
  });

  /// Build from a caught DioException. Handles:
  /// - network / timeout (status == null, userMessage = offline copy)
  /// - JSON body matching `ApiErrorEnvelope` (extracts code + errors)
  /// - non-JSON 5xx (falls back to status-based copy)
  factory ApiException.fromDio(DioException e) {
    // Offline / timeout — no server response at all.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return const ApiException(
          userMessage:
              'Could not reach the server. Check your internet connection.',
        );
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          userMessage:
              'The server is taking too long to respond. Please try again.',
        );
      default:
        break;
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;

    // Pull structured fields out of the envelope if the server
    // returned JSON that looks like one.
    String? code;
    String? requestId;
    int? retry;
    Map<String, String> fields = const {};
    String? serverMessage;

    if (data is Map) {
      final map = data.cast<String, dynamic>();
      code = map['code'] as String?;
      requestId = map['request_id'] as String?;
      final retryRaw = map['retry_after_seconds'];
      if (retryRaw is int) retry = retryRaw;
      final rawErrors = map['errors'];
      if (rawErrors is Map) {
        final out = <String, String>{};
        rawErrors.forEach((k, v) {
          if (v is List && v.isNotEmpty) {
            out[k.toString()] = v.first.toString();
          } else if (v is String) {
            out[k.toString()] = v;
          }
        });
        if (out.isNotEmpty) fields = out;
      }
      final msg = map['message'];
      if (msg is String && msg.isNotEmpty) {
        serverMessage = msg;
      } else if (msg is List && msg.isNotEmpty) {
        serverMessage = msg.first.toString();
      }
    }

    // Build userMessage with the same priority as admin-web.
    String userMessage;
    final codeDef = lookupErrorCode(code);
    if (codeDef != null) {
      userMessage = codeDef.userMessage;
    } else if (fields.isNotEmpty) {
      userMessage = fields.values.first;
      if (fields.length > 1) {
        userMessage =
            '$userMessage (+${fields.length - 1} more ${fields.length == 2 ? 'issue' : 'issues'})';
      }
    } else if (serverMessage != null && serverMessage.isNotEmpty) {
      userMessage = serverMessage;
    } else {
      userMessage = _friendlyStatusMessage(status);
    }

    return ApiException(
      status: status,
      code: code,
      fieldErrors: fields,
      retryAfterSeconds: retry,
      requestId: requestId,
      userMessage: userMessage,
    );
  }

  /// Build from an arbitrary thrown value. Safe for `catch (e)`
  /// blocks that might see a DioException, another ApiException,
  /// or a plain Object.
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return ApiException.fromDio(error);
    final text = error.toString();
    // Strip Dart's default `Exception: ` prefix if present.
    final cleaned =
        text.startsWith('Exception: ') ? text.substring('Exception: '.length) : text;
    return ApiException(
      userMessage: cleaned.length > 160 ? 'Something went wrong. Please try again.' : cleaned,
    );
  }

  /// No-response offline constructor; useful when a caller detects
  /// the device is offline before making a request.
  factory ApiException.offline() => const ApiException(
        userMessage:
            'You are offline. Check your internet connection and try again.',
      );

  @override
  String toString() => 'ApiException($status, $code): $userMessage';
}

String _friendlyStatusMessage(int? status) {
  if (status == null) return 'Something went wrong. Please try again.';
  if (status == 400) return 'That looks off — please check the form and try again.';
  if (status == 401) return 'Your session has expired. Please sign in again.';
  if (status == 403) return 'You do not have permission to do this.';
  if (status == 404) return 'We could not find what you were looking for.';
  if (status == 409) return 'This conflicts with existing data. Refresh and try again.';
  if (status == 422) return 'Some fields did not pass validation. Please review and retry.';
  if (status == 429) return 'You are going too fast. Please wait a moment and try again.';
  if (status >= 500) return 'Something went wrong on our end. Please try again in a minute.';
  return 'Something went wrong. Please try again.';
}
