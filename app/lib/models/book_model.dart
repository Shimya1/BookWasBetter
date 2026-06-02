import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum BookStatus { wantToRead, currentlyReading, finished, abandoned }

extension BookStatusExtension on BookStatus {
  String get displayName {
    switch (this) {
      case BookStatus.wantToRead:
        return 'Want to Read';
      case BookStatus.currentlyReading:
        return 'Reading';
      case BookStatus.finished:
        return 'Finished';
      case BookStatus.abandoned:
        return 'Abandoned';
    }
  }

  String get firestoreValue {
    switch (this) {
      case BookStatus.wantToRead:
        return 'wantToRead';
      case BookStatus.currentlyReading:
        return 'currentlyReading';
      case BookStatus.finished:
        return 'finished';
      case BookStatus.abandoned:
        return 'abandoned';
    }
  }

  static BookStatus fromString(String value) {
    switch (value) {
      case 'currentlyReading':
        return BookStatus.currentlyReading;
      case 'finished':
        return BookStatus.finished;
      case 'abandoned':
        return BookStatus.abandoned;
      default:
        return BookStatus.wantToRead;
    }
  }
}

class Book {
  final String id;
  final String userId;
  final String googleBooksId;
  final BookStatus status;
  final int currentChapter;
  final DateTime dateAdded;
  final DateTime? dateFinished;
  final String? review;
  final double? rating;

  Book({
    String? id,
    required this.userId,
    required this.googleBooksId,
    this.review,
    this.rating,
    this.status = BookStatus.wantToRead,
    this.currentChapter = 0,
    DateTime? dateAdded,
    this.dateFinished,
  })  : id = id ?? _uuid.v4(),
        dateAdded = dateAdded ?? DateTime.now();

  Book copyWith({
    BookStatus? status,
    int? currentChapter,
    DateTime? dateFinished,
    String? review,
    double? rating,
  }) {
    return Book(
      id: id,
      userId: userId,
      googleBooksId: googleBooksId,
      status: status ?? this.status,
      currentChapter: currentChapter ?? this.currentChapter,
      dateAdded: dateAdded,
      dateFinished: dateFinished ?? this.dateFinished,
      review: review,
      rating: rating,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'googleBooksId': googleBooksId,
      'status': status.firestoreValue,
      'currentChapter': currentChapter,
      'dateAdded': dateAdded.toIso8601String(),
      'dateFinished': dateFinished?.toIso8601String(),
      'review': review,
      'rating': rating,
    };
  }

  factory Book.fromMap(String id, Map<String, dynamic> map) {
    return Book(
      id: id,
      userId: map['userId'] as String,
      googleBooksId: map['googleBooksId'] as String? ?? '',
      status: BookStatusExtension.fromString(
          map['status'] as String? ?? 'wantToRead'),
      currentChapter: (map['currentChapter'] as num?)?.toInt() ?? 0,
      dateAdded: map['dateAdded'] != null
          ? DateTime.parse(map['dateAdded'] as String)
          : DateTime.now(),
      dateFinished: map['dateFinished'] != null
          ? DateTime.parse(map['dateFinished'] as String)
          : null,
      review: map['review'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble(),
    );
  }
}
