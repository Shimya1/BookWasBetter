import 'dart:convert';
import 'package:app/models/appState.dart';
import 'package:app/models/book_model.dart';
import 'package:app/services/google_books_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

const _fetchCoverUrl =
    'https://us-central1-thebookwasbetter-d4381.cloudfunctions.net/fetchAndStoreCover';

class BookSearchScreen extends StatefulWidget {
  final void Function(BookSearchResult)? onBookSelected;
  final String? clubId;
  const BookSearchScreen({super.key, this.onBookSelected, this.clubId});

  @override
  State<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends State<BookSearchScreen> {
  final _searchController = TextEditingController();
  final _googleBooksService = GoogleBooksService();
  Set<String> _clubReadIds = {};

  List<BookSearchResult> _results = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.clubId != null) {
      FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('libraryBooks')
          .get()
          .then((snap) {
        if (mounted) {
          setState(() {
            _clubReadIds = snap.docs
                .map((d) => d.data()['googleBooksId'] as String)
                .toSet();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      final results = await _googleBooksService.search(query);
      setState(() => _results = results);
    } catch (e) {
      setState(
          () => _error = 'Search failed. Check your connection and try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addBook(BookSearchResult result, BookStatus status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Prevent duplicates — check if this book is already in the library
    final alreadyAdded = context
        .read<StateModel>()
        .books
        .any((b) => b.googleBooksId == result.googleBooksId);

    if (alreadyAdded) {
      Navigator.of(context).pop(); // close the status picker
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${result.title}" is already in your library.'),
          backgroundColor: const Color.fromARGB(255, 146, 129, 129),
        ),
      );
      return;
    }

    // Show loading dialog while fetching and storing the cover
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: Color.fromARGB(255, 110, 60, 60),
        ),
      ),
    );

    try {
      // Fetch cover from Google Books and store in Firebase Storage
      final token = await user.getIdToken();
      final coverResponse = await http.post(
        Uri.parse(_fetchCoverUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'googleBooksId': result.googleBooksId}),
      );

      String coverUrl = result.coverUrl;
      if (coverResponse.statusCode == 200) {
        final data = jsonDecode(coverResponse.body) as Map<String, dynamic>;
        coverUrl = data['coverUrl'] as String? ?? result.coverUrl;
      }

      final updatedResult = BookSearchResult(
        googleBooksId: result.googleBooksId,
        title: result.title,
        author: result.author,
        coverUrl: coverUrl, // ← the Storage URL, not the original
        description: result.description,
      );

      await context.read<StateModel>().addBook(updatedResult, status);

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${result.title}" added to your log.'),
            backgroundColor: const Color.fromARGB(255, 110, 60, 60),
          ),
        );
        Navigator.of(context).pop(); // go back to book log
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add book: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddDialog(BookSearchResult result) {
    if (widget.onBookSelected != null) {
      widget.onBookSelected!(result);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 250, 243, 220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 70, 40, 20),
              ),
            ),
            Text(
              result.author,
              style: const TextStyle(
                fontSize: 14,
                color: Color.fromARGB(255, 120, 80, 50),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add to my log as:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color.fromARGB(255, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 12),
            _StatusOption(
              label: 'Want to Read',
              icon: Icons.bookmark_border,
              color: const Color.fromARGB(255, 30, 70, 140),
              onTap: () {
                Navigator.pop(ctx);
                _addBook(result, BookStatus.wantToRead);
              },
            ),
            _StatusOption(
              label: 'Currently Reading',
              icon: Icons.menu_book,
              color: const Color.fromARGB(255, 40, 100, 40),
              onTap: () {
                Navigator.pop(ctx);
                _addBook(result, BookStatus.currentlyReading);
              },
            ),
            _StatusOption(
              label: 'Finished',
              icon: Icons.check_circle_outline,
              color: const Color.fromARGB(255, 100, 60, 10),
              onTap: () {
                Navigator.pop(ctx);
                _addBook(result, BookStatus.finished);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 221, 209, 153),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 207, 178, 141),
        elevation: 0,
        title: const Text(
          'Search Books',
          style: TextStyle(
            color: Color.fromARGB(255, 70, 40, 20),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color.fromARGB(255, 110, 60, 60),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Title, author, or ISBN...',
                      hintStyle: const TextStyle(
                        color: Color.fromARGB(150, 70, 40, 20),
                      ),
                      filled: true,
                      fillColor: const Color.fromARGB(220, 255, 250, 235),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color.fromARGB(180, 110, 60, 60),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 110, 60, 60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 110, 60, 60),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 130, 40, 40),
                            ),
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Search for a book to add it to your log.'
                                  : 'No results found.',
                              style: const TextStyle(
                                color: Color.fromARGB(180, 70, 40, 20),
                              ),
                            ),
                          )
                        : Consumer<StateModel>(
                            builder: (context, state, _) {
                              return ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _results.length,
                                separatorBuilder: (_, __) => const Divider(
                                    color: Color.fromARGB(60, 110, 60, 60)),
                                itemBuilder: (context, index) {
                                  final result = _results[index];
                                  final inLibrary = widget.clubId != null
                                      ? _clubReadIds
                                          .contains(result.googleBooksId)
                                      : state.books.any((b) =>
                                          b.googleBooksId ==
                                          result.googleBooksId);
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        result.coverUrl,
                                        width: 44,
                                        height: 66,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 44,
                                          height: 66,
                                          color: const Color.fromARGB(
                                              255, 200, 180, 150),
                                          child: const Icon(Icons.menu_book,
                                              size: 24,
                                              color: Color.fromARGB(
                                                  120, 110, 60, 60)),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      result.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color.fromARGB(255, 70, 40, 20),
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          result.author,
                                          style: const TextStyle(
                                            color: Color.fromARGB(
                                                255, 120, 80, 50),
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (inLibrary) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            widget.clubId != null
                                                ? 'Already read by this club'
                                                : 'Already in your library',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color.fromARGB(
                                                  200, 110, 60, 60),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: inLibrary
                                        ? const Icon(Icons.check_circle,
                                            color: Color.fromARGB(
                                                200, 110, 60, 60),
                                            size: 22)
                                        : IconButton(
                                            icon: const Icon(
                                                Icons.add_circle_outline),
                                            color: const Color.fromARGB(
                                                255, 110, 60, 60),
                                            onPressed: () =>
                                                _showAddDialog(result),
                                          ),
                                    onTap: inLibrary
                                        ? null
                                        : () => _showAddDialog(result),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
