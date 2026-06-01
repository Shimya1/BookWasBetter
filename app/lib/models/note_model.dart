
import 'package:uuid/uuid.dart';

import 'tag_model.dart';

const uuid = Uuid();

class Note {
  final String userId;
  final String id;
  final String title;
  final String body;
  final String chapter;
  final bool public;
  final List<String> clubs;
  final List<Tag> tags = [];


  Note({
    required this.userId,
    String? id,
    required this.title,
    required this.body,
    required this.chapter,
    required this.public,
    required this.clubs,
     List<Tag>? tags,
  }) : id = id ?? uuid.v4();

  // Converts a Note to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'chapter': chapter,
      'public': public,
      'clubs': clubs,
    };
  }

  // Creates a Note from a Firestore document
  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      userId: map['userId'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      chapter: map['chapter'] as String,
      public: map['public'] as bool,
      clubs: List<String>.from(map['clubs'] ?? []),
      tags: (map['tags'] as List<dynamic>?)
          ?.map((tagMap) => Tag(
                name: tagMap['name'] as String,
                color: tagMap['color'] as String,
              ))
          .toList()
    );
  }
}
