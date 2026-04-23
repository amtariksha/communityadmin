/// Dart port of `communityos/packages/shared/src/error-codes.ts`.
///
/// When the server emits `envelope.code`, the client looks it up here
/// and prefers `userMessage` over whatever English string was in
/// `envelope.message`. That keeps messages stable across server-side
/// wording tweaks — and lets the UI branch on a code (e.g. show an
/// "Edit existing unit" button on a `unit_number_exists` conflict)
/// without matching English string content.
///
/// Keep this in sync with the TypeScript registry. Duplicate by hand;
/// drift risk is low because new codes are rarely added.
class ErrorCodeDef {
  /// Default HTTP status for this code (server may override).
  final int status;

  /// User-facing message. Under 100 chars, actionable.
  final String userMessage;

  const ErrorCodeDef({required this.status, required this.userMessage});
}

const Map<String, ErrorCodeDef> kErrorCodes = {
  // Auth (OTP)
  'otp_rate_limited': ErrorCodeDef(
    status: 429,
    userMessage:
        'Too many OTP requests for this number. Please wait a minute and try again.',
  ),
  'otp_expired_or_missing': ErrorCodeDef(
    status: 401,
    userMessage:
        'No active OTP for this number. Tap "Resend" and try again.',
  ),
  'otp_invalid': ErrorCodeDef(
    status: 401,
    userMessage: 'The OTP you entered is incorrect. Please try again.',
  ),

  // Units
  'unit_not_found': ErrorCodeDef(
    status: 404,
    userMessage: 'This unit no longer exists. It may have been removed.',
  ),
  'unit_has_active_members': ErrorCodeDef(
    status: 409,
    userMessage:
        'This unit still has active members. Remove them before deleting the unit.',
  ),
  'unit_number_exists': ErrorCodeDef(
    status: 409,
    userMessage:
        'A unit with this number already exists in this society.',
  ),

  // Vendors
  'vendor_name_exists': ErrorCodeDef(
    status: 409,
    userMessage: 'A vendor with this name already exists.',
  ),

  // Invoicing
  'invoice_already_cancelled': ErrorCodeDef(
    status: 400,
    userMessage: 'This invoice has already been cancelled.',
  ),
  'invoice_has_payments': ErrorCodeDef(
    status: 400,
    userMessage:
        'Cannot cancel an invoice with payments. Create a credit note instead.',
  ),
  'invoice_already_posted': ErrorCodeDef(
    status: 409,
    userMessage:
        'This invoice has already been posted and cannot be changed. Create a credit note to reverse it.',
  ),
  'invoice_already_paid': ErrorCodeDef(
    status: 409,
    userMessage:
        'This invoice is already fully paid. No more receipts can be added against it.',
  ),
  'amount_out_of_range': ErrorCodeDef(
    status: 400,
    userMessage:
        'The amount is outside the allowed range. Enter a positive value up to ₹1,00,00,000.',
  ),

  // Payments (Razorpay)
  'payment_signature_invalid': ErrorCodeDef(
    status: 400,
    userMessage:
        'The payment could not be verified. If money was deducted, it will be refunded within 5–7 working days.',
  ),
  'payment_webhook_signature_invalid': ErrorCodeDef(
    status: 400,
    userMessage: 'The payment gateway signature could not be verified.',
  ),
  'payment_already_refunded': ErrorCodeDef(
    status: 409,
    userMessage: 'This payment has already been refunded.',
  ),

  // Autopay subscriptions
  'subscription_not_active': ErrorCodeDef(
    status: 400,
    userMessage: 'Only active subscriptions can be paused.',
  ),
  'subscription_not_paused': ErrorCodeDef(
    status: 400,
    userMessage: 'Only paused subscriptions can be resumed.',
  ),
  'subscription_already_terminated': ErrorCodeDef(
    status: 400,
    userMessage: 'This subscription has already been cancelled.',
  ),

  // RBAC / permissions
  'role_cannot_self_demote': ErrorCodeDef(
    status: 403,
    userMessage:
        'You cannot remove your own admin role. Ask another admin to make the change.',
  ),
  'insufficient_permissions': ErrorCodeDef(
    status: 403,
    userMessage: 'You do not have permission to perform this action.',
  ),
};

/// Safe runtime lookup — returns null for unknown codes so a newer
/// server that emits a code this client doesn't recognise degrades
/// gracefully to the message/status fallback.
ErrorCodeDef? lookupErrorCode(String? code) {
  if (code == null || code.isEmpty) return null;
  return kErrorCodes[code];
}
