import 'package:community_admin/core/roles.dart';
import 'package:community_admin/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// D12 — the guard supervisor role was merged into security_supervisor; the
/// admin app lets in, and labels, only the role that absorbed it.
void main() {
  const retired = 'guard_' 'supervisor';

  test('the retired supervisor role no longer opens the admin app', () {
    expect(kAdminRoles, isNot(contains(retired)));
    final societies = filterSocietiesForAdminApp([
      Society(id: 's1', name: 'Old Role Society', roles: const [retired]),
      Society(id: 's2', name: 'Merged Role Society', roles: const ['security_supervisor']),
    ]);

    expect(societies.map((s) => s.id), ['s2']);
  });

  test('a security supervisor is shown as one', () {
    final society = Society(
      id: 's1',
      name: 'Test Society',
      roles: const ['tenant_resident', 'security_supervisor'],
    );

    expect(society.role, 'security_supervisor');
  });
}
