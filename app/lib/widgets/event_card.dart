import 'package:app/models/activity_model.dart';
import 'package:app/models/event_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {
  final ClubEvent event;
  final String clubId;
  final String ownerUid;
  const EventCard(
      {super.key, required this.event, required this.clubId, required this.ownerUid});

  String get _typeLabel => switch (event.type) {
        EventType.meeting => 'Meeting',
        EventType.bookSelection => 'Book Selection',
        EventType.misc => 'Misc',
      };

  Color get _typeColor => switch (event.type) {
        EventType.meeting => const Color.fromARGB(255, 180, 230, 180),
        EventType.bookSelection => const Color.fromARGB(255, 200, 220, 245),
        EventType.misc => const Color.fromARGB(255, 230, 210, 170),
      };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final canDelete = uid == event.createdBy || uid == ownerUid;
    final isAttending = event.isAttending(uid);
    final hour = event.dateTime.hour;
    final minute = event.dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final timeLabel = '$displayHour:$minute $period';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(220, 255, 250, 235),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withAlpha(30),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _typeLabel,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(180, 70, 40, 20),
                ),
              ),
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(180, 70, 40, 20),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Color.fromARGB(180, 170, 40, 40),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color.fromARGB(255, 70, 40, 20),
            ),
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.description,
              style: const TextStyle(
                fontSize: 13,
                color: Color.fromARGB(180, 70, 40, 20),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isAttending ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: isAttending
                    ? const Color.fromARGB(255, 40, 120, 40)
                    : const Color.fromARGB(150, 110, 60, 60),
              ),
              const SizedBox(width: 6),
              Text(
                isAttending ? 'Attending' : 'Not attending',
                style: TextStyle(
                  fontSize: 12,
                  color: isAttending
                      ? const Color.fromARGB(255, 40, 120, 40)
                      : const Color.fromARGB(150, 110, 60, 60),
                ),
              ),
              const Spacer(),
              Text(
                '${event.attendees.length} attending',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(150, 70, 40, 20),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final ref = FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('events')
                      .doc(event.id);
                  if (isAttending) {
                    ref.update({
                      'attendees': FieldValue.arrayRemove([uid])
                    });
                  } else {
                    ref.update({
                      'attendees': FieldValue.arrayUnion([uid])
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAttending
                        ? const Color.fromARGB(40, 40, 120, 40)
                        : const Color.fromARGB(40, 110, 60, 60),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAttending ? 'Leave' : 'Join',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAttending
                          ? const Color.fromARGB(255, 40, 120, 40)
                          : const Color.fromARGB(255, 110, 60, 60),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 255, 250, 235),
        title: const Text(
          'Delete Event?',
          style: TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
        ),
        content: Text(
          'Are you sure you want to delete "${event.title}"?',
          style: const TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color.fromARGB(200, 110, 60, 60)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color.fromARGB(255, 170, 40, 40),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .doc(event.id)
          .delete();

      try {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final actorName =
            (userDoc.data()?['displayName'] as String? ?? '').isNotEmpty
                ? userDoc.data()!['displayName'] as String
                : 'A member';

        final entry = ActivityEntry(
          type: ActivityType.eventDeleted,
          actorUid: uid,
          actorName: actorName,
          targetName: event.title,
        );

        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('activity')
            .doc(entry.id)
            .set(entry.toMap());
      } catch (e) {
        debugPrint('Activity write failed: $e');
      }
    }
  }
}