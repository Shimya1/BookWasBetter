import 'package:app/models/book_view_model.dart';
import 'package:app/models/club_library_model.dart';
import 'package:app/models/note_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:app/models/appState.dart';
import 'package:app/models/book_model.dart';
import 'package:provider/provider.dart';

class ClubLibraryDetailScreen extends StatelessWidget {
  final String clubId;
  final ClubLibraryEntry entry;

  const ClubLibraryDetailScreen({
    super.key,
    required this.clubId,
    required this.entry,
  });

  String get _dateRange {
    final start = DateFormat.yMMMd().format(entry.selectedAt);
    if (entry.finishedAt == null) return 'Currently reading — started $start';
    final end = DateFormat.yMMMd().format(entry.finishedAt!);
    return 'Read $start – $end';
  }

  String get _attribution {
    if (entry.selectionMethod == BookSelectionMethod.election) {
      return 'Selected by club election';
    }
    return 'Picked by ${entry.selectedByName ?? 'the owner'}';
  }

  static Color _statusBg(BookStatus s) => switch (s) {
        BookStatus.currentlyReading => const Color.fromARGB(255, 180, 230, 180),
        BookStatus.wantToRead => const Color.fromARGB(255, 200, 220, 245),
        BookStatus.finished => const Color.fromARGB(255, 230, 210, 170),
        BookStatus.abandoned => const Color.fromARGB(255, 230, 200, 200),
      };

  static Color _statusFg(BookStatus s) => switch (s) {
        BookStatus.currentlyReading => const Color.fromARGB(255, 40, 100, 40),
        BookStatus.wantToRead => const Color.fromARGB(255, 30, 70, 140),
        BookStatus.finished => const Color.fromARGB(255, 100, 60, 10),
        BookStatus.abandoned => const Color.fromARGB(255, 130, 40, 40),
      };

  void _showAddToLibrarySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 250, 243, 220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to my library as:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 12),
            ...BookStatus.values.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _statusBg(s),
                      shape: BoxShape.circle,
                      border: Border.all(color: _statusFg(s), width: 1.5),
                    ),
                  ),
                  title: Text(
                    s.displayName,
                    style: TextStyle(
                        color: _statusFg(s), fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await context.read<StateModel>().addBookToPersonalLibrary(
                          googleBooksId: entry.googleBooksId,
                          status: s,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('"${entry.title}" added to your library.'),
                          backgroundColor:
                              const Color.fromARGB(255, 110, 60, 60),
                        ),
                      );
                    }
                  },
                )),
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
        title: Text(
          entry.title,
          style: const TextStyle(
              color: Color.fromARGB(255, 70, 40, 20),
              fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 110, 60, 60)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.coverUrl,
                  width: 90,
                  height: 130,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 130,
                    color: const Color.fromARGB(255, 200, 180, 150),
                    child: const Icon(Icons.menu_book,
                        size: 36, color: Color.fromARGB(120, 110, 60, 60)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 70, 40, 20)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.author,
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 120, 80, 50)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _dateRange,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(200, 110, 60, 60)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _attribution,
                      style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color.fromARGB(180, 110, 60, 60)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('library_books')
                .doc(entry.googleBooksId)
                .get(),
            builder: (context, snap) {
              final description = snap.data?.data()?['description'] as String?;
              if (description == null || description.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  description,
                  style: const TextStyle(
                      color: Color.fromARGB(220, 70, 40, 20), height: 1.4),
                ),
              );
            },
          ),
          const Text(
            'CLUB NOTES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color.fromARGB(160, 70, 40, 20),
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<HttpsCallableResult>(
            future: FirebaseFunctions.instance
                .httpsCallable('getClubBookNotes')
                .call({
              'clubId': clubId,
              'googleBooksId': entry.googleBooksId,
            }),
            builder: (context, snap) {
              if (snap.hasError) {
                debugPrint('Club notes fetch failed: ${snap.error}');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Could not load notes: ${snap.error}',
                    style:
                        const TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final rawNotes =
                  (snap.data!.data['notes'] as List<dynamic>? ?? []);
              final notes = rawNotes
                  .map((n) => Note.fromMap(
                      n['id'] as String, n as Map<String, dynamic>))
                  .toList();
              if (notes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No public notes for this book yet.',
                    style: TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
                  ),
                );
              }
              return Column(
                children: notes.map((n) => _ClubNoteCard(note: n)).toList(),
              );
            },
          ),
          Consumer<StateModel>(
            builder: (context, state, _) {
              final myBook = state.books.cast<BookView?>().firstWhere(
                    (b) => b!.googleBooksId == entry.googleBooksId,
                    orElse: () => null,
                  );

              if (myBook != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 15, color: Color.fromARGB(160, 70, 40, 20)),
                      const SizedBox(width: 6),
                      const Text(
                        'In your library: ',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color.fromARGB(160, 70, 40, 20)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusBg(myBook.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          myBook.status.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusFg(myBook.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _showAddToLibrarySheet(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add to my library'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color.fromARGB(255, 110, 60, 60),
                    side: const BorderSide(
                        color: Color.fromARGB(255, 110, 60, 60)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClubNoteCard extends StatelessWidget {
  final Note note;
  const _ClubNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(note.userId).get(),
      builder: (context, snap) {
        final authorName =
            snap.data?.data()?['displayName'] as String? ?? 'A member';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color.fromARGB(220, 255, 250, 235),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 70, 40, 20)),
                    ),
                  ),
                  Text(
                    authorName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Color.fromARGB(180, 110, 60, 60)),
                  ),
                ],
              ),
              if (note.chapter > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Chapter ${note.chapter}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color.fromARGB(150, 110, 60, 60),
                      fontWeight: FontWeight.w500),
                ),
              ],
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note.body,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(200, 70, 40, 20),
                      height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
