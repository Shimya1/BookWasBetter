import 'package:app/models/club_library_model.dart';
import 'package:app/models/note_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
        iconTheme:
            const IconThemeData(color: Color.fromARGB(255, 110, 60, 60)),
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
                    style: const TextStyle(
                        color: Color.fromARGB(200, 70, 40, 20)),
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