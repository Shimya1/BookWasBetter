enum ClubRole { founder, member }

class ClubMember {
  final String uid;
  final ClubRole role;
  final DateTime joinedAt;

  ClubMember({
    required this.uid,
    required this.role,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role == ClubRole.founder ? 'founder' : 'member',
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory ClubMember.fromMap(Map<String, dynamic> map) {
    return ClubMember(
      uid: map['uid'] as String,
      role: map['role'] == 'founder' ? ClubRole.founder : ClubRole.member,
      joinedAt: DateTime.parse(map['joinedAt'] as String),
    );
  }
}