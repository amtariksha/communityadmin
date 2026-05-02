/// Client-side input validators. Mirror the server-side Zod helpers
/// in `communityos/packages/shared/src/schemas/common.ts` so the
/// mobile app rejects bad data at the keyboard instead of waiting
/// for a 400 round-trip.
///
/// Every validator returns `String?` — null on valid, error message
/// on invalid. Plug directly into `TextFormField.validator:`.
///
/// Usage:
///   TextFormField(
///     validator: Validators.indianPhone,
///     ...
///   )
class Validators {
  // Matches admin web `^(\+91)?[6-9]\d{9}$`. Accepts 10-digit Indian
  // mobile starting 6/7/8/9, with an optional +91 prefix.
  // Deliberately rejects 0000000000 / 1234567890 / 0123456789 so junk
  // contact numbers can't slip into the database.
  static final RegExp _indianPhone = RegExp(r'^(\+91)?[6-9]\d{9}$');

  // Demo / E2E account phones — recognised server-side as bypass
  // numbers (`auth.service.ts:isDemoPhone`). Range:
  // +910000000007..+910000000100. Allowed alongside real mobiles so
  // the admin app can seed demo logins.
  static final RegExp _demoIndianPhone =
      RegExp(r'^\+910000000(00[7-9]|0[1-9]\d|100)$');

  // Unicode letters + basic punctuation. Rejects SQL-meta sequences
  // (apostrophe-semicolon etc.) and empty strings.
  static final RegExp _personName = RegExp(
    r"^[\p{L}][\p{L}\s.'-]{1,199}$",
    unicode: true,
  );

  // Descriptive prose — letters, digits, spaces, basic punctuation.
  static final RegExp _descriptive = RegExp(
    r'^[\p{L}\p{N}\s.,\-/()&#+:]+$',
    unicode: true,
  );

  /// Indian mobile number. Strips whitespace + hyphens before
  /// checking. Empty string returns null (use `TextFormField.required`
  /// or a separate check for required-ness).
  static String? indianPhone(String? input) {
    final raw = (input ?? '').trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) return null;
    final canonical = raw.startsWith('+91') ? raw : '+91$raw';
    if (!_indianPhone.hasMatch(raw) &&
        !_demoIndianPhone.hasMatch(canonical)) {
      return 'Enter a 10-digit Indian mobile starting 6–9 (optional +91 prefix).';
    }
    return null;
  }

  /// Same as [indianPhone] but returns an error when empty.
  static String? requiredIndianPhone(String? input) {
    final trimmed = (input ?? '').trim();
    if (trimmed.isEmpty) return 'Phone number is required.';
    return indianPhone(input);
  }

  /// Normalize a validated phone to canonical `+91XXXXXXXXXX`.
  /// Returns null if the input isn't a valid Indian mobile — pair
  /// with [indianPhone] before calling.
  static String? canonicalIndianPhone(String? input) {
    final raw = (input ?? '').trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) return null;
    final canonical = raw.startsWith('+91') ? raw : '+91$raw';
    if (!_indianPhone.hasMatch(raw) &&
        !_demoIndianPhone.hasMatch(canonical)) {
      return null;
    }
    return canonical;
  }

  /// Person name — min 2 chars, max 200, Unicode letters + basic punctuation.
  static String? personName(String? input) {
    final trimmed = (input ?? '').trim();
    if (trimmed.length < 2) return 'Name must be at least 2 characters.';
    if (trimmed.length > 200) return 'Name must be at most 200 characters.';
    if (!_personName.hasMatch(trimmed)) {
      return 'Name may only contain letters, spaces, dots, hyphens and apostrophes.';
    }
    return null;
  }

  /// Email — simple `x@y.z` check. Empty string returns null (use
  /// a separate required check).
  static String? email(String? input) {
    final trimmed = (input ?? '').trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Short descriptive prose — visitor purpose, parcel description,
  /// narration. Rejects 1–2 char junk and SQL-meta noise.
  static String? descriptiveText(
    String? input, {
    int min = 3,
    int max = 500,
    String label = 'Value',
  }) {
    final trimmed = (input ?? '').trim();
    if (trimmed.length < min) {
      return '$label must be at least $min characters.';
    }
    if (trimmed.length > max) {
      return '$label must be at most $max characters.';
    }
    if (!_descriptive.hasMatch(trimmed)) {
      return '$label may only contain letters, numbers, spaces and basic punctuation.';
    }
    return null;
  }

  // Prevent accidental instantiation.
  Validators._();
}
