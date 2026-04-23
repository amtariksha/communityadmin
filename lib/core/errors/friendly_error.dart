import 'package:flutter/material.dart';

import 'api_exception.dart';

/// Convenience wrapper over [ApiException.from] — gives you the
/// friendly string for any thrown value.
///
/// Migration note: the existing `friendlyErrorMessage(Object)` in
/// `lib/widgets/error_widget.dart` predates this module and does
/// roughly the same thing with simpler extraction logic. It's kept
/// for backward-compat; new code should prefer
/// [ApiException.from(e).userMessage] so per-field errors + the
/// error-codes registry are respected.
String friendlyErrorString(Object error) =>
    ApiException.from(error).userMessage;

/// Show a friendly SnackBar for any caught error. Use inside catch
/// blocks in place of:
///
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text('Error: $e')),
///   );
///
/// — which leaks raw Dart exception strings to users. This helper
/// routes through [ApiException.from] so the user always sees
/// human-friendly copy, and the field-level errors surface on the
/// form if the caller wants them.
///
/// Returns the `ApiException` so the caller can also inspect
/// `.fieldErrors` and highlight the offending input inline.
ApiException showFriendlySnackBar(
  BuildContext context,
  Object error, {
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
}) {
  final exc = ApiException.from(error);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(exc.userMessage),
        duration: duration,
        action: action,
      ),
    );
  }
  return exc;
}
