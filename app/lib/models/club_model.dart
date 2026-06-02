import 'package:app/models/tag_model.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

const _uuid = Uuid();

class Club {
  final String id;
  final String name;
  final String founderUid;
  final String inviteCode;
  final DateTime createdAt;
  final List<Tag> tags = [];

  Club({
    String? id,
    required this.name,
    required this.founderUid,
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
      'founderUid': founderUid,
      'inviteCode': inviteCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Club.fromMap(String id, Map<String, dynamic> map) {
    return Club(
      id: id,
      name: map['name'] as String,
      founderUid: map['founderUid'] as String,
      inviteCode: map['inviteCode'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}