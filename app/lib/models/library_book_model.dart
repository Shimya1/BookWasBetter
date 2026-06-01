class LibraryBook {
  final String googleBooksId;
  final String title;
  final String author;
  final String coverUrl;
  final String description;
  final int numUsersBorrowing;

  LibraryBook({
    required this.googleBooksId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
    this.numUsersBorrowing = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'googleBooksId': googleBooksId,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'description': description,
      'numUsersBorrowing': numUsersBorrowing,
    };
  }

  factory LibraryBook.fromMap(Map<String, dynamic> map) {
    return LibraryBook(
      googleBooksId: map['googleBooksId'] as String,
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      description: map['description'] as String? ?? '',
      numUsersBorrowing: (map['numUsersBorrowing'] as num?)?.toInt() ?? 1,
    );
  }
}