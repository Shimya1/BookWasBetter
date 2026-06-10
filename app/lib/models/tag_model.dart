import 'package:uuid/uuid.dart';

const _tagUuid = Uuid();

class Tag {
  final String id;
  final String name;
  final int color; // Flutter Color.value — 32-bit ARGB int

  Tag({
    String? id,
    required this.name,
    required this.color,
  }) : id = id ?? _tagUuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as int,
    );
  }

  
}


