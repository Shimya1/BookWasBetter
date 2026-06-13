import 'package:uuid/uuid.dart';

class Message {
  final String id;
  final String uid;
  final String displayName;
  final String avatarUrl;
  final String text;
  final DateTime createdAt;

  Message({
    String? id,
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.text,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Message.fromMap(String id, Map<String, dynamic> map) => Message(
        id: id,
        uid: map['uid'] as String,
        displayName: map['displayName'] as String,
        avatarUrl: map['avatarUrl'] as String? ?? '',
        text: map['text'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}