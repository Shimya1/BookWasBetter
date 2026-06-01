import 'package:app/models/appState.dart';
import 'package:app/screens/clubs/create_club_screen.dart';
import 'package:app/screens/clubs/join_club_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/screens/clubs/club_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClubsScreen extends StatelessWidget {
  const ClubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              state.clubs.isEmpty
                  ? _EmptyState(onCreate: () => _openCreate(context), onJoin: () => _openJoin(context))
                  : _ClubList(onCreate: () => _openCreate(context), onJoin: () => _openJoin(context)),

              // FAB row — create and join buttons
              Positioned(
                bottom: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'join',
                      onPressed: () => _openJoin(context),
                      backgroundColor: const Color.fromARGB(255, 160, 110, 60),
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.login),
                      label: const Text('Join Club'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'create',
                      onPressed: () => _openCreate(context),
                      backgroundColor: const Color.fromARGB(255, 110, 60, 60),
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Club'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCreate(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateClubScreen()),
      );

  void _openJoin(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JoinClubScreen()),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _EmptyState({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined,
                size: 64, color: Color.fromARGB(100, 110, 60, 60)),
            const SizedBox(height: 16),
            const Text(
              'No clubs yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a club and invite your friends,\nor join one with an invite code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color.fromARGB(180, 70, 40, 20),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubList extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _ClubList({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final clubs = context.watch<StateModel>().clubs;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      itemCount: clubs.length,
      itemBuilder: (context, index) {
        final club = clubs[index];
        final isFounder = club.founderUid ==
            FirebaseAuth.instance.currentUser?.uid;
        return Container(
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
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color.fromARGB(255, 110, 60, 60),
              child: Text(
                club.name[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              club.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color.fromARGB(255, 70, 40, 20),
              ),
            ),
            subtitle: Text(
              club.founderUid == FirebaseAuth.instance.currentUser?.uid
                  ? 'Founder'
                  : 'Member',
              style: const TextStyle(
                fontSize: 12,
                color: Color.fromARGB(180, 110, 60, 60),
              ),
            ),
            trailing: const Icon(Icons.chevron_right,
                color: Color.fromARGB(150, 110, 60, 60)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClubDetailScreen(club: club),
              ),
            ),
          ),
        );
      },
    );
  }
}