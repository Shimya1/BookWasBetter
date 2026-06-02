import 'package:uuid/uuid.dart';

const _noteUuid = Uuid();

class Note {
  final String id;
  final String userId;
  final String googleBooksId;
  final String title;
  final String body;
  final int chapter;
  final bool public;
  final List<String> clubs;
  final List<String> tagIds;
  final DateTime createdAt;

  Note({
    String? id,
    required this.userId,
    required this.googleBooksId,
    required this.title,
    required this.body,
    this.chapter = 0,
    this.public = false,
    this.clubs = const [],
    this.tagIds = const [],
    DateTime? createdAt,
  })  : id = id ?? _noteUuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'googleBooksId': googleBooksId,
      'title': title,
      'body': body,
      'chapter': chapter,
      'public': public,
      'clubs': clubs,
      'tagIds': tagIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      userId: map['userId'] as String,
      googleBooksId: map['googleBooksId'] as String? ?? '',
      title: map['title'] as String,
      body: map['body'] as String,
      chapter: (map['chapter'] as num?)?.toInt() ?? 0,
      public: map['public'] as bool? ?? false,
      clubs: List<String>.from(map['clubs'] ?? []),
      tagIds: List<String>.from(map['tagIds'] ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Note copyWith({
    String? title,
    String? body,
    int? chapter,
    bool? public,
    List<String>? clubs,
    List<String>? tagIds,
  }) {
    return Note(
      id: id,
      userId: userId,
      googleBooksId: googleBooksId,
      title: title ?? this.title,
      body: body ?? this.body,
      chapter: chapter ?? this.chapter,
      public: public ?? this.public,
      clubs: clubs ?? this.clubs,
      tagIds: tagIds ?? this.tagIds,
      createdAt: createdAt,
    );
  }
}