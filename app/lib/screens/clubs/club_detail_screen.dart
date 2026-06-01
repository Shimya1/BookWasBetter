import 'package:app/models/appState.dart';
import 'package:app/models/club_member_model.dart';
import 'package:app/models/club_model.dart';
import 'package:app/models/join_request_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ClubDetailScreen extends StatelessWidget {
  final Club club;
  const ClubDetailScreen({super.key, required this.club});

  bool get _isFounder =>
      FirebaseAuth.instance.currentUser?.uid == club.founderUid;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 240, 228, 185),
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(2250,110,60,60),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            club.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Members'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(club: club, isFounder: _isFounder),
            _MembersTab(club: club, isFounder: _isFounder),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }

}

//Overview tab shows invite code, join requests (founder only), current book, and recent activity
class _OverviewTab extends StatelessWidget {
  final Club club;
  final bool isFounder;
  const _OverviewTab({required this.club, required this.isFounder});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Invite code card
        _InviteCodeCard(inviteCode: club.inviteCode),
        const SizedBox(height: 16),

        // Join requests (founder only)
        if (isFounder) ...[
          _JoinRequestsPanel(club: club),
          const SizedBox(height: 16),
        ],

        // Current book placeholder
        _PlaceholderCard(
          icon: Icons.menu_book,
          title: 'Current Book',
          message: 'No book selected yet.\nStart a vote to pick one!',
        ),
        const SizedBox(height: 16),

        // Activity placeholder
        _PlaceholderCard(
          icon: Icons.dynamic_feed_outlined,
          title: 'Recent Activity',
          message: 'Activity will appear here\nas your club gets reading.',
        ),
      ],
    );
  }
}



// Members tab shows list of members, with founder at top and "Admin" badge, and option to remove members (founder only)
class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;
  const _InviteCodeCard({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          const Icon(Icons.vpn_key_outlined,
              color: Color.fromARGB(200, 110, 60, 60)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INVITE CODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color.fromARGB(160, 70, 40, 20),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                inviteCode,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Color.fromARGB(255, 110, 60, 60),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy,
                color: Color.fromARGB(180, 110, 60, 60)),
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite code copied to clipboard.'),
                  backgroundColor: Color.fromARGB(255, 110, 60, 60),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


//Join requests panel shows list of pending join requests with option to approve/deny (founder only)
class _JoinRequestsPanel extends StatelessWidget {
  final Club club;
  const _JoinRequestsPanel({required this.club});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(club.id)
          .collection('joinRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!.docs
            .map((doc) => JoinRequest.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_outlined,
                        size: 18,
                        color: Color.fromARGB(200, 110, 60, 60)),
                    const SizedBox(width: 8),
                    Text(
                      'Join Requests (${requests.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 70, 40, 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color.fromARGB(40, 110, 60, 60)),
              ...requests.map((request) => _JoinRequestTile(
                    club: club,
                    request: request,
                  )),
            ],
          ),
        );
      },
    );
  }
}


//joinRequstTile is a ListTile showing the requester's uid and buttons to accept/decline the request (founder only)
class _JoinRequestTile extends StatelessWidget {
  final Club club;
  final JoinRequest request;
  const _JoinRequestTile({required this.club, required this.request});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color.fromARGB(255, 200, 180, 150),
            child: Text(
              request.uid.substring(0, 2).toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                color: Color.fromARGB(255, 110, 60, 60),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.uid,
              style: const TextStyle(
                fontSize: 13,
                color: Color.fromARGB(200, 70, 40, 20),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Decline
          IconButton(
            icon: const Icon(Icons.close,
                color: Color.fromARGB(200, 170, 40, 40), size: 20),
            tooltip: 'Decline',
            onPressed: () => context.read<StateModel>().respondToJoinRequest(
                  clubId: club.id,
                  requestUid: request.uid,
                  accept: false,
                ),
          ),
          // Accept
          IconButton(
            icon: const Icon(Icons.check,
                color: Color.fromARGB(200, 40, 120, 40), size: 20),
            tooltip: 'Accept',
            onPressed: () => context.read<StateModel>().respondToJoinRequest(
                  clubId: club.id,
                  requestUid: request.uid,
                  accept: true,
                ),
          ),
        ],
      ),
    );
  }
}

//members tab shows list of members, with founder at top and "Admin" badge, and option to remove members (founder only)
class _MembersTab extends StatelessWidget {
  final Club club;
  final bool isFounder;
  const _MembersTab({required this.club, required this.isFounder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(club.id)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color.fromARGB(255, 110, 60, 60),
            ),
          );
        }

        final members = snapshot.data!.docs
            .map((doc) =>
                ClubMember.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        members.sort((a, b) {
          if (a.role == ClubRole.founder) return -1;
          if (b.role == ClubRole.founder) return 1;
          return 0;
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isMe = member.uid == FirebaseAuth.instance.currentUser?.uid;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(member.uid)
                  .get(),
              builder: (context, profileSnapshot) {
                String displayName = isMe ? 'You' : 'Loading...';
                String avatarUrl = '';

                if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
                  final data = profileSnapshot.data!.data()
                      as Map<String, dynamic>;
                  final name = data['displayName'] as String? ?? '';
                  displayName = isMe
                      ? 'You'
                      : name.isNotEmpty
                          ? name
                          : 'Unknown';
                  avatarUrl = data['avatarUrl'] as String? ?? '';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          member.role == ClubRole.founder
                              ? const Color.fromARGB(255, 110, 60, 60)
                              : const Color.fromARGB(255, 200, 180, 150),
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              displayName.isNotEmpty &&
                                      displayName != 'Loading...'
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: member.role == ClubRole.founder
                                    ? Colors.white
                                    : const Color.fromARGB(255, 110, 60, 60),
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 70, 40, 20),
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      member.role == ClubRole.founder ? 'Founder' : 'Member',
                      style: TextStyle(
                        fontSize: 12,
                        color: member.role == ClubRole.founder
                            ? const Color.fromARGB(200, 110, 60, 60)
                            : const Color.fromARGB(150, 70, 40, 20),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}


//history tab shows list of past books with dates, and option to leave reviews (coming soon)
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Book history coming soon.',
        style: TextStyle(
          color: Color.fromARGB(180, 70, 40, 20),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

//placeholder card with icon, title, and message, used for current book and activity feed sections on overview tab
class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: const Color.fromARGB(200, 110, 60, 60)),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color.fromARGB(160, 70, 40, 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color.fromARGB(150, 70, 40, 20),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}