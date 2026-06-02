import 'package:app/models/appState.dart';
import 'package:app/models/book_view_model.dart';
import 'package:app/screens/book_log/book_detail_screen.dart';
import 'package:app/screens/book_log/book_search_screen.dart';
import 'package:app/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BookLogScreen extends StatelessWidget {
  const BookLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Tab bar
          Container(
            color: const Color.fromARGB(255, 207, 178, 141),
            child: TabBar(
              labelColor: const Color.fromARGB(255, 110, 60, 60),
              unselectedLabelColor: const Color.fromARGB(180, 70, 40, 20),
              indicatorColor: const Color.fromARGB(255, 110, 60, 60),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Reading'),
                Tab(text: 'Want to Read'),
                Tab(text: 'Finished'),
                Tab(text: 'Abandoned'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 221, 209, 153),
                    Color.fromARGB(255, 207, 178, 141),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Consumer<StateModel>(
                builder: (context, state, _) {
                  return Stack(
                    children: [
                      TabBarView(
                        children: [
                          _BookList(
                            books: state.currentlyReading,
                            emptyMessage: 'No books in progress.\nAdd one below!',
                          ),
                          _BookList(
                            books: state.wantToRead,
                            emptyMessage: 'Your reading list is empty.\nFind something to read!',
                          ),
                          _BookList(
                            books: state.finishedBooks,
                            emptyMessage: 'No finished books yet.\nKeep reading!',
                          ),
                          _BookList(
                            books: state.abandonedBooks,
                            emptyMessage: 'No abandoned books.\nGood going!',
                          ),
                        ],
                      ),

                      // FAB to add a book
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: FloatingActionButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BookSearchScreen(),
                            ),
                          ),
                          backgroundColor:
                              const Color.fromARGB(255, 110, 60, 60),
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final List<BookView> books;
  final String emptyMessage;

  const _BookList({required this.books, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: Color.fromARGB(180, 70, 40, 20),
            height: 1.6,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 90),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          book: book,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookDetailScreen(book: book),
            ),
          ),
        );
      },
    );
  }
}
