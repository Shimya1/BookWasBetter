import 'package:app/models/appState.dart';
import 'package:app/models/club_model.dart';
import 'package:app/models/election_model.dart';
import 'package:app/screens/book_log/book_search_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ElectionScreen extends StatelessWidget {
  final String clubId;
  const ElectionScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final clubs = context.watch<StateModel>().clubs;
    Club? club;
    for (final c in clubs) {
      if (c.id == clubId) {
        club = c;
        break;
      }
    }

    if (club == null) {
      return const Scaffold(body: Center(child: Text('Club not found.')));
    }

    if (club.activeElectionId == null) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 221, 209, 153),
        appBar: AppBar(title: const Text('Vote for the Next Book')),
        body: const Center(child: Text('This vote has closed.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('elections')
          .doc(club.activeElectionId)
          .snapshots(),
      builder: (context, electionSnap) {
        if (!electionSnap.hasData || !electionSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final election = Election.fromMap(
            electionSnap.data!.id, electionSnap.data!.data()!);

        return _ElectionBody(club: club!, election: election);
      },
    );
  }
}

class _ElectionBody extends StatelessWidget {
  final Club club;
  final Election election;
  const _ElectionBody({required this.club, required this.election});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isOwner = club.ownerUid == uid;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 221, 209, 153),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 207, 178, 141),
        elevation: 0,
        title: const Text(
          'Vote for the Next Book',
          style: TextStyle(
              color: Color.fromARGB(255, 70, 40, 20),
              fontWeight: FontWeight.w600),
        ),
        iconTheme:
            const IconThemeData(color: Color.fromARGB(255, 110, 60, 60)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(club.id)
            .collection('elections')
            .doc(election.id)
            .collection('nominations')
            .snapshots(),
        builder: (context, nomSnap) {
          final nominations = (nomSnap.data?.docs ?? [])
              .map((d) => Nomination.fromMap(d.data()))
              .toList();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('clubs')
                .doc(club.id)
                .collection('elections')
                .doc(election.id)
                .collection('votes')
                .snapshots(),
            builder: (context, voteSnap) {
              final votes = (voteSnap.data?.docs ?? [])
                  .map((d) => Vote.fromMap(d.data()))
                  .toList();

              if (election.isTied) {
                return _TiedView(
                  club: club,
                  election: election,
                  nominations: nominations,
                  isOwner: isOwner,
                );
              }
              if (election.isVoting) {
                return _VotingView(
                  club: club,
                  election: election,
                  nominations: nominations,
                  votes: votes,
                  uid: uid,
                );
              }
              return _NominatingView(
                club: club,
                election: election,
                nominations: nominations,
                uid: uid,
              );
            },
          );
        },
      ),
    );
  }
}

class _NominatingView extends StatelessWidget {
  final Club club;
  final Election election;
  final List<Nomination> nominations;
  final String uid;

  const _NominatingView({
    required this.club,
    required this.election,
    required this.nominations,
    required this.uid,
  });

  void _openPicker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookSearchScreen(
          onBookSelected: (result) async {
            await context.read<StateModel>().submitNomination(
                  clubId: club.id,
                  electionId: election.id,
                  book: result,
                );
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Nomination? myNomination;
    for (final n in nominations) {
      if (n.uid == uid) {
        myNomination = n;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Nominations close ${_formatDateTime(election.nominationsCloseAt)}.',
          style: const TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openPicker(context),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
              myNomination == null ? 'Submit Your Pick' : 'Change Your Pick'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 110, 60, 60),
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'NOMINATIONS SO FAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color.fromARGB(160, 70, 40, 20),
          ),
        ),
        const SizedBox(height: 8),
        if (nominations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No one has submitted a book yet.'),
          ),
        ...nominations.map((n) => _BookRow(
              title: n.title,
              author: n.author,
              coverUrl: n.coverUrl,
              trailing: n.uid == uid
                  ? const Text('Your pick',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color.fromARGB(200, 110, 60, 60)))
                  : null,
            )),
      ],
    );
  }
}

class _VotingView extends StatelessWidget {
  final Club club;
  final Election election;
  final List<Nomination> nominations;
  final List<Vote> votes;
  final String uid;

  const _VotingView({
    required this.club,
    required this.election,
    required this.nominations,
    required this.votes,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final byBook = <String, Nomination>{};
    for (final n in nominations) {
      byBook.putIfAbsent(n.googleBooksId, () => n);
    }

    Vote? myVote;
    for (final v in votes) {
      if (v.uid == uid) {
        myVote = v;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${votes.length} of ${election.eligibleVoterUids.length} members have voted. '
          'Voting closes ${_formatDateTime(election.votingEndTime)}.',
          style: const TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
        ),
        const SizedBox(height: 16),
        if (byBook.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No one submitted a book to vote on.'),
          ),
        ...byBook.values.map((n) {
          final isMyVote = myVote?.googleBooksId == n.googleBooksId;
          return _BookRow(
            title: n.title,
            author: n.author,
            coverUrl: n.coverUrl,
            trailing: ElevatedButton(
              onPressed: isMyVote
                  ? null
                  : () => context.read<StateModel>().castVote(
                        clubId: club.id,
                        electionId: election.id,
                        googleBooksId: n.googleBooksId,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isMyVote
                    ? Colors.grey
                    : const Color.fromARGB(255, 110, 60, 60),
                foregroundColor: Colors.white,
              ),
              child: Text(isMyVote ? 'Your Vote' : 'Vote'),
            ),
          );
        }),
      ],
    );
  }
}

class _TiedView extends StatelessWidget {
  final Club club;
  final Election election;
  final List<Nomination> nominations;
  final bool isOwner;

  const _TiedView({
    required this.club,
    required this.election,
    required this.nominations,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final tiedIds = election.tiedBookIds ?? [];
    final tiedBooks = <String, Nomination>{};
    for (final n in nominations) {
      if (tiedIds.contains(n.googleBooksId)) {
        tiedBooks.putIfAbsent(n.googleBooksId, () => n);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "It's a tie!",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 70, 40, 20)),
        ),
        const SizedBox(height: 6),
        Text(
          isOwner
              ? 'Pick the winner to settle it.'
              : 'Waiting for the club owner to break the tie.',
          style: const TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
        ),
        const SizedBox(height: 16),
        ...tiedBooks.values.map((n) => _BookRow(
              title: n.title,
              author: n.author,
              coverUrl: n.coverUrl,
              trailing: isOwner
                  ? ElevatedButton(
                      onPressed: () =>
                          context.read<StateModel>().resolveTie(
                                clubId: club.id,
                                electionId: election.id,
                                googleBooksId: n.googleBooksId,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 110, 60, 60),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Choose This One'),
                    )
                  : null,
            )),
      ],
    );
  }
}

class _BookRow extends StatelessWidget {
  final String title;
  final String author;
  final String coverUrl;
  final Widget? trailing;

  const _BookRow({
    required this.title,
    required this.author,
    required this.coverUrl,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              coverUrl,
              width: 40,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 40,
                height: 58,
                color: const Color.fromARGB(255, 200, 180, 150),
                child: const Icon(Icons.menu_book,
                    size: 20, color: Color.fromARGB(120, 110, 60, 60)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 70, 40, 20))),
                Text(author,
                    style: const TextStyle(
                        color: Color.fromARGB(255, 120, 80, 50),
                        fontSize: 13)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.month}/${dt.day} at $hour:$minute $period';
}