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
  final String role;

  Society({required this.id, required this.name, required this.role});

  factory Society.fromJson(Map<String, dynamic> json) {
    return Society(
      id: json['id'] as String? ?? json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? json['tenantName'] as String? ?? '',
      role: json['role'] as String? ??
          ((json['roles'] as List<dynamic>?)?.isNotEmpty == true
              ? (json['roles'] as List<dynamic>).first as String
              : 'member'),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}
