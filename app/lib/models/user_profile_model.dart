class UserProfile {
  final String uid;
  final String displayName;
  final String avatarUrl;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.avatarUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String? ?? 'Anonymous',
      avatarUrl: map['avatarUrl'] as String? ?? '',
    );
  }
}