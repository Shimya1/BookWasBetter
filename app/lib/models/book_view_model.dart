import 'package:app/models/book_model.dart';
import 'package:app/models/library_book_model.dart';

class BookView {
  final Book book;
  final LibraryBook libraryBook;

  BookView({required this.book, required this.libraryBook});

  // Delegate user-specific fields to Book
  String get id => book.id;
  String get userId => book.userId;
  String get googleBooksId => book.googleBooksId;
  BookStatus get status => book.status;
  int get currentChapter => book.currentChapter;
  DateTime get dateAdded => book.dateAdded;
  DateTime? get dateFinished => book.dateFinished;
  double? get rating => book.rating;
  String? get review => book.review;

  // Delegate metadata to LibraryBook
  String get title => libraryBook.title;
  String get author => libraryBook.author;
  String get coverUrl => libraryBook.coverUrl;
  String get description => libraryBook.description;

  // copyWith proxies to Book, keeps libraryBook intact
  BookView copyWith({
    BookStatus? status,
    int? currentChapter,
    DateTime? dateFinished,
    double? rating,
    String? review,
  }) {
    return BookView(
      book: book.copyWith(
        status: status,
        currentChapter: currentChapter,
        dateFinished: dateFinished,
        rating: rating,
        review: review,
      ),
      libraryBook: libraryBook,
    );
  }
}
