import 'package:community_admin/models/user.dart';

/// App-target → role allowlist, hand-ported from QA Round 14 plan §C
/// (`packages/shared/src/roles.ts` once D1 ships codegen — round-14
/// §F.3 follow-up).
///
/// Single source of truth for which roles can use the admin Flutter
/// app. `super_admin` is implicit and listed verbatim — they can
/// access every app. Drift risk: if shared/src/roles.ts changes
/// before codegen lands, this list must be updated by hand.
const List<String> kAdminRoles = <String>[
  'super_admin',
  'community_admin',
  'committee_member',
  'moderator',
  'auditor',
  'facility_supervisor',
  'security_supervisor',
  'accountant',
  'guard_supervisor',
];

/// Filter a user's society list down to the ones where the user has
/// at least one role allowlisted for the admin app.
///
/// Used at login (`auth_service.verifyOtp`) and on auth state
/// rehydration so the admin app never shows societies where the user
/// has only resident or guard roles.
///
/// Reads `Society.roles` (array). When the backend is still on the
/// scalar-`role` shape (pre-D1 #14-1d), `User.fromJson` already
/// wraps the scalar into a single-element array, so this function
/// works against both shapes uniformly.
List<Society> filterSocietiesForAdminApp(List<Society> societies) {
  return societies
      .where((s) => s.roles.any(kAdminRoles.contains))
      .toList(growable: false);
}

/// Return the role label to display in the admin app for a society
/// where the user holds multiple roles (e.g. `tenant + committee_member`
/// → "Committee Member" in the admin app, even though "Tenant" is
/// also valid). Falls back to the legacy scalar `role` getter for
/// older payloads, then to the empty string.
String displayRoleForAdmin(Society s) {
  for (final r in s.roles) {
    if (kAdminRoles.contains(r)) return r;
  }
  // Legacy fallback. Society.role getter returns the first allowlisted
  // role from `roles[]`, or `roles.first`, or `'member'`.
  return s.role;
}
