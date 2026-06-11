import 'package:uuid/uuid.dart';

enum EventType { meeting, bookSelection, misc }

class ClubEvent {
  final String id;
  final String title;
  final String description;
  final EventType type;
  final DateTime dateTime;
  final String createdBy;
  final List<String> attendees;

  ClubEvent({
    String? id,
    required this.title,
    required this.description,
    required this.type,
    required this.dateTime,
    required this.createdBy,
    this.attendees = const [],
  }) : id = id ?? const Uuid().v4();

  bool isAttending(String uid) => attendees.contains(uid);

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'type': type.name,
        'dateTime': dateTime.toIso8601String(),
        'createdBy': createdBy,
        'attendees': attendees,
      };

  factory ClubEvent.fromMap(String id, Map<String, dynamic> map) => ClubEvent(
        id: id,
        title: map['title'] as String,
        description: map['description'] as String,
        type: EventType.values.byName(map['type'] as String),
        dateTime: DateTime.parse(map['dateTime'] as String),
        createdBy: map['createdBy'] as String,
        attendees: List<String>.from(map['attendees'] ?? []),
      );
}