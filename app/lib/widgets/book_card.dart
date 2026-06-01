import 'package:app/models/book_model.dart';
import 'package:flutter/material.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const BookCard({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromARGB(220, 255, 250, 235),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: book.coverUrl.isNotEmpty
                  ? Image.network(
                      book.coverUrl,
                      width: 70,
                      height: 105,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderCover(),
                    )
                  : _placeholderCover(),
            ),

            // Book info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color.fromARGB(255, 70, 40, 20),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color.fromARGB(255, 120, 80, 50),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Status badge
                    _StatusBadge(status: book.status),

                    // Chapter progress (only for currently reading)
                    if (book.status == BookStatus.currentlyReading) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.bookmark_outlined,
                            size: 14,
                            color: Color.fromARGB(255, 110, 60, 60),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            book.currentChapter > 0
                                ? 'Chapter ${book.currentChapter}'
                                : 'Not started',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color.fromARGB(255, 110, 60, 60),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Chevron
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 40),
              child: Icon(
                Icons.chevron_right,
                color: Color.fromARGB(150, 110, 60, 60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      width: 70,
      height: 105,
      color: const Color.fromARGB(255, 200, 180, 150),
      child: const Icon(
        Icons.menu_book,
        color: Color.fromARGB(120, 110, 60, 60),
        size: 32,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      BookStatus.currentlyReading => (
          'Reading',
          const Color.fromARGB(255, 180, 230, 180),
          const Color.fromARGB(255, 40, 100, 40),
        ),
      BookStatus.wantToRead => (
          'Want to Read',
          const Color.fromARGB(255, 200, 220, 245),
          const Color.fromARGB(255, 30, 70, 140),
        ),
      BookStatus.finished => (
          'Finished',
          const Color.fromARGB(255, 230, 210, 170),
          const Color.fromARGB(255, 100, 60, 10),
        ),
      BookStatus.abandoned => (
          'Abandoned',
          const Color.fromARGB(255, 230, 200, 200),
          const Color.fromARGB(255, 130, 40, 40),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
