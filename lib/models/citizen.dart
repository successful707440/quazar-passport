class Citizen {
  final String id;
  final String name;
  final String publicKey;
  final String status;
  final String? role;
  final bool? isCouncilMember;
  final bool? canVeto;
  final int createdAt;
  final bool passportIssued;
  final int? passportExpires;

  Citizen({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.status,
    this.role,
    this.isCouncilMember,
    this.canVeto,
    required this.createdAt,
    required this.passportIssued,
    this.passportExpires,
  });

  factory Citizen.fromJson(Map<String, dynamic> json) {
    return Citizen(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      publicKey: json['public_key'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      role: json['role'] as String?,
      isCouncilMember: json['is_council_member'] as bool?,
      canVeto: json['can_veto'] as bool?,
      createdAt: json['created_at'] as int? ?? 0,
      passportIssued: json['passport_issued'] as bool? ?? false,
      passportExpires: json['passport_expires'] as int?,
    );
  }
}
