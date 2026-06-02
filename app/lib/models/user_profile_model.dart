import 'package:app/models/tag_model.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String avatarUrl;
  final List<Tag> tags;
  final List<String> memberClubIds;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.avatarUrl = '',
    this.tags = const [],
    this.memberClubIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'tags': tags.map((tag) => tag.toMap()).toList(),
      'memberClubIds': memberClubIds,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String? ?? 'Anonymous',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      tags: (map['tags'] as List<dynamic>?)
              ?.map((tag) => Tag.fromMap(tag as Map<String, dynamic>))
              .toList() ??
           [],
      memberClubIds: (map['memberClubIds'] as List<dynamic>?)
              ?.map((id) => id as String)
              .toList() ??
           [],
    );
  }
}
