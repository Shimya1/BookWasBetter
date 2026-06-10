import 'package:app/models/tag_model.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

const _uuid = Uuid();

class Club {
  final String id;
  final String name;
  final String ownerUid;
  final String inviteCode;
  final DateTime createdAt;
  final List<String> memberUids;
  final List<Tag> tags = [];

  Club({
    String? id,
    required this.name,
    required this.ownerUid,
    this.memberUids = const [],
    String? inviteCode,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        inviteCode = inviteCode ?? _generateInviteCode(),
        createdAt = createdAt ?? DateTime.now();

  static String _generateInviteCode() {
    const chars = 'ABCDEF0123456789';
    final rand = Random.secure();
    return List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'inviteCode': inviteCode,
      'createdAt': createdAt.toIso8601String(),
      'memberUids': memberUids,
    };
  }

  factory Club.fromMap(String id, Map<String, dynamic> map) {
    return Club(
      id: id,
      name: map['name'] as String,
      ownerUid: map['ownerUid'] as String,
      inviteCode: map['inviteCode'] as String,
      memberUids: List<String>.from(map['memberUids'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}