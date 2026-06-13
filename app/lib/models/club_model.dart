import 'package:app/models/activity_model.dart';
import 'package:app/models/event_model.dart';
import 'package:app/models/message_model.dart';
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
  final List<ClubEvent> events;
  final List<String> memberUids;
  final List<ActivityEntry> activities;
  final List<Tag> tags = [];
  final List<Message> messages;

  Club({
    String? id,
    required this.name,
    required this.ownerUid,
    this.memberUids = const [],
    this.activities = const [],
    this.events = const [],
    this.messages = const [],
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


  Club copyWith({
  List<ActivityEntry>? activities,
  List<ClubEvent>? events,
  List<Message>? messages,
}) {
  return Club(
    id: id,
    name: name,
    ownerUid: ownerUid,
    inviteCode: inviteCode,
    memberUids: memberUids,
    activities: activities ?? this.activities,
    events: events ?? this.events,
    messages: messages ?? this.messages,
  );
}
}