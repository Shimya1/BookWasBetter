import 'package:uuid/uuid.dart';

enum BookSelectionMethod { owner, election }

extension BookSelectionMethodExtension on BookSelectionMethod {
  String get firestoreValue => name;

  static BookSelectionMethod fromString(String value) {
    switch (value) {
      case 'election':
        return BookSelectionMethod.election;
      default:
        return BookSelectionMethod.owner;
    }
  }
}

/// A single past-or-current "active book" period for a club.
/// Denormalized snapshot (title/author/coverUrl) so the library list
/// can be rendered with a single query — no per-book join reads.
class ClubLibraryEntry {
  final String id;
  final String googleBooksId;
  final String title;
  final String author;
  final String coverUrl;
  final DateTime selectedAt;
  final DateTime? finishedAt;
  final BookSelectionMethod selectionMethod;
  final String? selectedByUid;
  final String? selectedByName;

  ClubLibraryEntry({
    String? id,
    required this.googleBooksId,
    required this.title,
    required this.author,
    required this.coverUrl,
    DateTime? selectedAt,
    this.finishedAt,
    this.selectionMethod = BookSelectionMethod.owner,
    this.selectedByUid,
    this.selectedByName,
  })  : id = id ?? const Uuid().v4(),
        selectedAt = selectedAt ?? DateTime.now();

  /// True while this is the club's current active book (not yet replaced).
  bool get isCurrent => finishedAt == null;

  Map<String, dynamic> toMap() => {
        'googleBooksId': googleBooksId,
        'title': title,
        'author': author,
        'coverUrl': coverUrl,
        'selectedAt': selectedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt?.toUtc().toIso8601String(),
        'selectionMethod': selectionMethod.firestoreValue,
        'selectedByUid': selectedByUid,
        'selectedByName': selectedByName,
      };

  factory ClubLibraryEntry.fromMap(String id, Map<String, dynamic> map) =>
      ClubLibraryEntry(
        id: id,
        googleBooksId: map['googleBooksId'] as String,
        title: map['title'] as String? ?? '',
        author: map['author'] as String? ?? '',
        coverUrl: map['coverUrl'] as String? ?? '',
        selectedAt: DateTime.parse(map['selectedAt'] as String).toLocal(),
        finishedAt: map['finishedAt'] != null
            ? DateTime.parse(map['finishedAt'] as String).toLocal()
            : null,
        selectionMethod: BookSelectionMethodExtension.fromString(
            map['selectionMethod'] as String? ?? 'owner'),
        selectedByUid: map['selectedByUid'] as String?,
        selectedByName: map['selectedByName'] as String?,
      );

  ClubLibraryEntry copyWith({DateTime? finishedAt}) => ClubLibraryEntry(
        id: id,
        googleBooksId: googleBooksId,
        title: title,
        author: author,
        coverUrl: coverUrl,
        selectedAt: selectedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        selectionMethod: selectionMethod,
        selectedByUid: selectedByUid,
        selectedByName: selectedByName,
      );
}