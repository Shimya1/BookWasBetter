import 'package:uuid/uuid.dart';

enum ActivityType { memberJoined, memberLeft, bookSelected, clubCreated, ownershipTransferred, eventCreated, eventDeleted }

class ActivityEntry {
  final String id;
  final ActivityType type;
  final String actorUid;
  final String actorName;
  final DateTime createdAt;
  final String? targetName;

  ActivityEntry({
    String? id,
    required this.type,
    required this.actorUid,
    required this.actorName,
    DateTime? createdAt,
    this.targetName, 
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  String get description => switch (type) {
        ActivityType.clubCreated => '$actorName created the club',
        ActivityType.memberJoined => '$actorName joined the club',
        ActivityType.eventCreated => '$actorName created a new event: ${targetName ?? 'an event'}',
        ActivityType.eventDeleted => '$actorName deleted an event: ${targetName ?? 'an event'}',
        ActivityType.memberLeft => '$actorName left the club',
        ActivityType.bookSelected => '$actorName selected a new book',
        ActivityType.ownershipTransferred => '$actorName transferred ownership to ${targetName ?? 'a member'}',

      };

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'actorUid': actorUid,
        'actorName': actorName,
        'createdAt': createdAt.toIso8601String(),
        if (targetName != null) 'targetName': targetName,
      };

  factory ActivityEntry.fromMap(String id, Map<String, dynamic> map) =>
      ActivityEntry(
        id: id,
        type: ActivityType.values.byName(map['type'] as String),
        actorUid: map['actorUid'] as String,
        actorName: map['actorName'] as String,
        targetName: map['targetName'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}