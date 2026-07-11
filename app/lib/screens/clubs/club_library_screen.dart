import 'package:app/models/club_library_model.dart';
import 'package:app/screens/clubs/club_library_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClubLibraryScreen extends StatelessWidget {
  final String clubId;
  const ClubLibraryScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('libraryBooks')
          .orderBy('selectedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data!.docs
            .map((d) => ClubLibraryEntry.fromMap(d.id, d.data()))
            .toList();

        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "No books in this club's library yet.",
                style: TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
              ),
            ),
          );
        }

        ClubLibraryEntry? current;
        final past = <ClubLibraryEntry>[];
        for (final e in entries) {
          if (e.isCurrent && current == null) {
            current = e;
          } else {
            past.add(e);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (current != null) ...[
              const _SectionHeader(label: 'CURRENTLY READING'),
              const SizedBox(height: 8),
              _LibraryEntryCard(clubId: clubId, entry: current),
              const SizedBox(height: 20),
            ],
            if (past.isNotEmpty) ...[
              const _SectionHeader(label: 'PREVIOUSLY READ'),
              const SizedBox(height: 8),
              ...past.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LibraryEntryCard(clubId: clubId, entry: e),
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Color.fromARGB(160, 70, 40, 20),
      ),
    );
  }
}

class _LibraryEntryCard extends StatelessWidget {
  final String clubId;
  final ClubLibraryEntry entry;
  const _LibraryEntryCard({required this.clubId, required this.entry});

  String get _dateRange {
    final start = DateFormat.yMMM().format(entry.selectedAt);
    if (entry.finishedAt == null) return 'Since $start';
    final end = DateFormat.yMMM().format(entry.finishedAt!);
    return '$start – $end';
  }

  String get _attribution {
    if (entry.selectionMethod == BookSelectionMethod.election) {
      return 'Selected by election';
    }
    return 'Picked by ${entry.selectedByName ?? 'the owner'}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ClubLibraryDetailScreen(clubId: clubId, entry: entry),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color.fromARGB(220, 255, 250, 235),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                entry.coverUrl,
                width: 44,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 44,
                  height: 64,
                  color: const Color.fromARGB(255, 200, 180, 150),
                  child: const Icon(Icons.menu_book,
                      size: 22, color: Color.fromARGB(120, 110, 60, 60)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 70, 40, 20)),
                  ),
                  Text(
                    entry.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color.fromARGB(255, 120, 80, 50),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateRange,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color.fromARGB(180, 110, 60, 60)),
                  ),
                  Text(
                    _attribution,
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Color.fromARGB(150, 110, 60, 60)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color.fromARGB(120, 110, 60, 60)),
          ],
        ),
      ),
    );
  }
}