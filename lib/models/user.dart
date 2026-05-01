class User {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final bool isSuperAdmin;
  final List<Society> societies;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.isSuperAdmin = false,
    required this.societies,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final societies = (json['societies'] as List<dynamic>?)
            ?.map((s) => Society.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    final role = json['role'] as String? ??
        (societies.isNotEmpty ? societies.first.role : 'member');

    return User(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      role: role,
      isSuperAdmin: json['isSuperAdmin'] as bool? ?? false,
      societies: societies,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'isSuperAdmin': isSuperAdmin,
        'societies': societies.map((s) => s.toJson()).toList(),
      };
}

class Society {
  final String id;
  final String name;

  /// All roles the user holds in this society. Post-Round-14 the
  /// backend `/auth/me` response carries an array (e.g. `tenant +
  /// committee_member`); pre-Round-14 it carries a scalar `role`
  /// which `fromJson` wraps into a single-element list so this field
  /// is always populated.
  final List<String> roles;

  Society({
    required this.id,
    required this.name,
    required this.roles,
  });

  /// Legacy scalar role accessor — kept for back-compat with screens
  /// that read `society.role` directly (e.g. settings, dashboard).
  /// Prefers an admin-allowlisted role when one is present so the
  /// admin app's society chip reads e.g. "Committee Member" rather
  /// than "Tenant" for hybrid users. Defensive fallback: first role,
  /// then `'member'`.
  String get role {
    const adminAllowlist = <String>{
      'super_admin',
      'community_admin',
      'committee_member',
      'moderator',
      'auditor',
      'facility_supervisor',
      'security_supervisor',
      'accountant',
      'guard_supervisor',
    };
    for (final r in roles) {
      if (adminAllowlist.contains(r)) return r;
    }
    return roles.isEmpty ? 'member' : roles.first;
  }

  factory Society.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final List<String> roles;
    if (rawRoles is List && rawRoles.isNotEmpty) {
      roles = rawRoles.map((e) => e.toString()).toList(growable: false);
    } else if (json['role'] is String &&
        (json['role'] as String).isNotEmpty) {
      // Pre-Round-14 scalar shape — wrap into single-element array.
      roles = [json['role'] as String];
    } else {
      roles = const [];
    }
    return Society(
      id: json['id'] as String? ?? json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? json['tenantName'] as String? ?? '',
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'roles': roles,
      };
}
