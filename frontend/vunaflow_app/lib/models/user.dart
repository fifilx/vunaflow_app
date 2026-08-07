class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role; // client | staff | admin
  final String? branchId;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.branchId,
  });

  bool get isStaff => role == 'staff' || role == 'admin';
  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        fullName: json['full_name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        role: json['role'] ?? 'client',
        branchId: json['branch_id'],
      );
}
