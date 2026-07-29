import 'dart:async';
import 'package:app/models/activity_model.dart';
import 'package:app/models/appState.dart';
import 'package:app/models/club_member_model.dart';
import 'package:app/models/club_model.dart';
import 'package:app/models/event_model.dart';
import 'package:app/models/join_request_model.dart';
import 'package:app/models/message_model.dart';
import 'package:app/models/library_book_model.dart';
import 'package:app/screens/book_log/book_search_screen.dart';
import 'package:app/services/google_books_service.dart';
import 'package:app/widgets/event_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/models/event_model.dart';
import 'package:app/screens/clubs/create_event_screen.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:app/screens/clubs/election_screen.dart';
import 'package:app/screens/clubs/club_library_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ClubDetailScreen extends StatefulWidget {
  final Club club;
  const ClubDetailScreen({super.key, required this.club});

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _activitySub;
  StreamSubscription? _eventsSub;
  StreamSubscription? _messagesSub;
  List<ActivityEntry> _activities = [];
  List<ClubEvent> _events = [];
  List<Message> _messages = [];
  late TabController _tabController;
  int _unreadMessages = 0;
  DateTime _lastReadAt = DateTime.fromMillisecondsSinceEpoch(0);

  Club get _club {
    final stateModel = context.read<StateModel>();
    final base = stateModel.clubs.firstWhere(
      (c) => c.id == widget.club.id,
      orElse: () => widget.club,
    );
    return base.copyWith(
      activities: _activities,
      events: _events,
      messages: _messages,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 2 && mounted) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final now = DateTime.now();
        setState(() {
          _unreadMessages = 0;
          _lastReadAt = now;
        });
        FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.club.id)
            .collection('members')
            .doc(uid)
            .update({'lastReadAt': now.toIso8601String()});
      }
    });
    _activitySub = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.club.id)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      final entries = snapshot.docs
          .map((doc) => ActivityEntry.fromMap(doc.id, doc.data()))
          .toList();
      if (mounted) {
        setState(() {
          _activities = entries;
        });
      }
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _eventsSub = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.club.id)
        .collection('events')
        .where('dateTime', isGreaterThanOrEqualTo: today.toIso8601String())
        .orderBy('dateTime')
        .snapshots()
        .listen((snapshot) {
      final events = snapshot.docs
          .map((doc) => ClubEvent.fromMap(doc.id, doc.data()))
          .toList();
      if (mounted) {
        setState(() {
          _events = events;
        });
      }
    });

    _initLastReadAt().then((_) {
      _messagesSub = FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.club.id)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final messages = snapshot.docs
            .map((doc) => Message.fromMap(doc.id, doc.data()))
            .toList();

        final newUnread = _tabController.index != 2
            ? messages.where((m) => m.createdAt.isAfter(_lastReadAt)).length
            : 0;

        setState(() {
          _messages = messages;
          _unreadMessages = newUnread;
        });
      });
    });
  }

  Future<void> _initLastReadAt() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final memberDoc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.club.id)
        .collection('members')
        .doc(uid)
        .get();

    if (memberDoc.exists && mounted) {
      final stored = memberDoc.data()?['lastReadAt'] as String?;
      if (stored != null) {
        final parsedTime = DateTime.parse(stored);
        if (parsedTime.isAfter(_lastReadAt)) {
          setState(() {
            _lastReadAt = parsedTime;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _activitySub?.cancel();
    _eventsSub?.cancel();
    _tabController.dispose();

    super.dispose();
  }

  bool get _isOwner => FirebaseAuth.instance.currentUser?.uid == _club.ownerUid;

  @override
  Widget build(BuildContext context) {
    context.watch<StateModel>();
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 228, 185),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 110, 60, 60),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.white),
            tooltip: 'Members',
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: const Color.fromARGB(255, 240, 228, 185),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _MembersSheet(club: _club),
            ),
          ),
          if (_isOwner && _club.memberUids.length == 1)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              tooltip: 'Delete club',
              onPressed: () => _confirmDelete(context),
            ),
          if (_isOwner && _club.memberUids.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              tooltip: 'Transfer ownership',
              onPressed: () => _confirmTransfer(context),
            ),
          if (!_isOwner)
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              tooltip: 'Leave club',
              onPressed: () => _confirmLeave(context),
            ),
        ],
        title: Text(
          _club.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Library'),
            const Tab(text: 'Events'),
            Tab(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Text('Chat'),
                  if (_unreadMessages > 0)
                    Positioned(
                      top: -6,
                      right: -14,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 170, 40, 40),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_unreadMessages',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(club: _club, isOwner: _isOwner),
          ClubLibraryScreen(clubId: _club.id),
          _EventsTab(club: _club),
          _ChatTab(club: _club, streamedMessages: _club.messages),
        ],
      ),
    );
  }

  Future<void> _confirmTransfer(BuildContext context) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(_club.id)
        .collection('members')
        .get();

    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final otherMembers =
        snapshot.docs.where((doc) => doc.id != currentUid).toList();

    if (otherMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other members to transfer ownership to.'),
          backgroundColor: Color.fromARGB(255, 110, 60, 60),
        ),
      );
      return;
    }

    // Load display names
    final memberProfiles = await Future.wait(
      otherMembers.map((doc) =>
          FirebaseFirestore.instance.collection('users').doc(doc.id).get()),
    );

    if (!context.mounted) return;

    final selectedUid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 255, 250, 235),
        title: const Text(
          'Transfer Ownership',
          style: TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: memberProfiles.length,
            itemBuilder: (ctx, i) {
              final data =
                  memberProfiles[i].data() as Map<String, dynamic>? ?? {};
              final name = (data['displayName'] as String? ?? '').isNotEmpty
                  ? data['displayName'] as String
                  : 'Unknown';
              return ListTile(
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 70, 40, 20),
                  ),
                ),
                onTap: () => Navigator.pop(ctx, memberProfiles[i].id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color.fromARGB(200, 110, 60, 60)),
            ),
          ),
        ],
      ),
    );

    if (selectedUid == null || !context.mounted) return;

    // Second confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 255, 250, 235),
        title: const Text(
          'Are you sure?',
          style: TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
        ),
        content: const Text(
          'You will become a regular member and cannot undo this yourself.',
          style: TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
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
              'Transfer',
              style: TextStyle(
                color: Color.fromARGB(255, 170, 40, 40),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<StateModel>().transferOwnership(
            clubId: _club.id,
            newOwnerUid: selectedUid,
          );
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 255, 250, 235),
        title: const Text(
          'Leave Club?',
          style: TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
        ),
        content: Text(
          'Are you sure you want to leave ${_club.name}?',
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
              'Leave',
              style: TextStyle(
                color: Color.fromARGB(255, 170, 40, 40),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<StateModel>().leaveClub(_club.id);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 255, 250, 235),
        title: const Text(
          'Delete Club?',
          style: TextStyle(
            color: Color.fromARGB(255, 170, 40, 40),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will permanently delete the club and all of its history, members, and activity. This cannot be undone.',
          style: TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
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
              'Delete Forever',
              style: TextStyle(
                color: Color.fromARGB(255, 170, 40, 40),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<StateModel>().deleteClub(_club.id);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Club club;
  final bool isOwner;
  const _OverviewTab({required this.club, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Invite code card
        _InviteCodeCard(inviteCode: club.inviteCode),
        const SizedBox(height: 16),

        // Join requests (owner only)
        if (isOwner) ...[
          _JoinRequestsPanel(club: club),
          const SizedBox(height: 16),
        ],

        // Current book
        _CurrentBookCard(club: club, isOwner: isOwner),
        const SizedBox(height: 16),

        if (club.activeElectionId != null) ...[
          _ElectionCard(club: club),
          const SizedBox(height: 16),
        ],

        _RecentActivityCard(activities: club.activities),
      ],
    );
  }
}

// ─── Invite Code Card ─────────────────────────────────────────────────────────

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
            icon:
                const Icon(Icons.copy, color: Color.fromARGB(180, 110, 60, 60)),
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

// ─── Join Requests Panel ──────────────────────────────────────────────────────

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
            .map((doc) =>
                JoinRequest.fromMap(doc.data() as Map<String, dynamic>))
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
                        size: 18, color: Color.fromARGB(200, 110, 60, 60)),
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

class _JoinRequestTile extends StatelessWidget {
  final Club club;
  final JoinRequest request;
  const _JoinRequestTile({required this.club, required this.request});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(request.uid).get(),
      builder: (context, snapshot) {
        String displayName = 'Loading...';
        String avatarUrl = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['displayName'] as String? ?? '';
          displayName = name.isNotEmpty ? name : 'Unknown';
          avatarUrl = data['avatarUrl'] as String? ?? '';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color.fromARGB(255, 200, 180, 150),
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        displayName.isNotEmpty && displayName != 'Loading...'
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 110, 60, 60),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
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
                onPressed: () =>
                    context.read<StateModel>().respondToJoinRequest(
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
                onPressed: () =>
                    context.read<StateModel>().respondToJoinRequest(
                          clubId: club.id,
                          requestUid: request.uid,
                          accept: true,
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Recent Activity Card ─────────────────────────────────────────────────
class _RecentActivityCard extends StatelessWidget {
  final List<ActivityEntry> activities;
  const _RecentActivityCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dynamic_feed_outlined,
                  size: 18, color: Color.fromARGB(200, 110, 60, 60)),
              SizedBox(width: 8),
              Text(
                'RECENT ACTIVITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color.fromARGB(160, 70, 40, 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activities.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.history,
                        size: 14, color: Color.fromARGB(150, 110, 60, 60)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color.fromARGB(200, 70, 40, 20),
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(entry.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color.fromARGB(130, 70, 40, 20),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Events Tab ──────────────────────────────────────────────────────────────
class _EventsTab extends StatefulWidget {
  final Club club;
  const _EventsTab({required this.club});

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<ClubEvent> _eventsForDay(DateTime day) {
    return widget.club.events
        .where((e) =>
            e.dateTime.year == day.year &&
            e.dateTime.month == day.month &&
            e.dateTime.day == day.day)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _selectedDay == null
        ? _eventsForDay(DateTime.now())
        : _eventsForDay(_selectedDay!);

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 1)),
          lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _eventsForDay,
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Color.fromARGB(150, 110, 60, 60),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Color.fromARGB(255, 110, 60, 60),
              shape: BoxShape.circle,
            ),
            weekendTextStyle:
                TextStyle(color: Color.fromARGB(200, 110, 60, 60)),
            defaultTextStyle: TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
            outsideTextStyle: TextStyle(color: Color.fromARGB(80, 70, 40, 20)),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: Color.fromARGB(255, 70, 40, 20),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: Color.fromARGB(200, 110, 60, 60),
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: Color.fromARGB(200, 110, 60, 60),
            ),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle:
                TextStyle(color: Color.fromARGB(180, 70, 40, 20), fontSize: 12),
            weekendStyle: TextStyle(
                color: Color.fromARGB(180, 110, 60, 60), fontSize: 12),
          ),
          calendarFormat: CalendarFormat.month,
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              final uid = FirebaseAuth.instance.currentUser!.uid;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: events.map((e) {
                  final event = e as ClubEvent;
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: event.isAttending(uid)
                          ? const Color.fromARGB(255, 40, 120, 40)
                          : const Color.fromARGB(255, 110, 60, 60),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),

        const Divider(height: 1, color: Color.fromARGB(40, 110, 60, 60)),

        // Event list for selected day
        Expanded(
          child: selectedEvents.isEmpty
              ? const Center(
                  child: Text(
                    'No events on this day.',
                    style: TextStyle(
                      color: Color.fromARGB(150, 70, 40, 20),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) => EventCard(
                    event: selectedEvents[index],
                    clubId: widget.club.id,
                    ownerUid: widget.club.ownerUid,
                  ),
                ),
        ),

        // Add event button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEventScreen(clubId: widget.club.id),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 110, 60, 60),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Chat Tab ──────────────────────────────────────────────────────────────
class _ChatTab extends StatefulWidget {
  final Club club;
  final List<Message> streamedMessages;
  const _ChatTab({required this.club, required this.streamedMessages});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _olderMessages = [];
  DocumentSnapshot? _oldestDoc;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _initialPaginationDone = false;

  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _setOldestDoc();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setOldestDoc() async {
    if (widget.streamedMessages.isEmpty) return;
    final oldest = widget.streamedMessages.last;
    final doc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.club.id)
        .collection('messages')
        .doc(oldest.id)
        .get();
    _oldestDoc = doc;
    _initialPaginationDone = true;
  }

  Future<void> _loadMore() async {
    if (_loadingMore ||
        !_hasMore ||
        _oldestDoc == null ||
        !_initialPaginationDone) return;
    setState(() => _loadingMore = true);

    final snapshot = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.club.id)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_oldestDoc!)
        .limit(_pageSize)
        .get();

    if (!mounted) return;

    final more = snapshot.docs
        .map((doc) => Message.fromMap(doc.id, doc.data()))
        .toList();

    setState(() {
      _olderMessages.addAll(more);
      _oldestDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _oldestDoc;
      _hasMore = snapshot.docs.length == _pageSize;
      _loadingMore = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final profile = context.read<StateModel>().profile;
    final message = Message(
      uid: profile!.uid,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl ?? '',
      text: text,
    );

    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.club.id)
        .collection('messages')
        .doc(message.id)
        .set(message.toMap());
  }

  List<Message> get _allMessages {
    final streamedIds = widget.streamedMessages.map((m) => m.id).toSet();
    final older =
        _olderMessages.where((m) => !streamedIds.contains(m.id)).toList();
    return [...widget.streamedMessages, ...older];
  }

  @override
  Widget build(BuildContext context) {
    final messages = _allMessages;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet. Say hello!',
                    style: TextStyle(
                      color: Color.fromARGB(150, 70, 40, 20),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            color: Color.fromARGB(255, 110, 60, 60),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    final message = messages[index];
                    final isMe =
                        message.uid == FirebaseAuth.instance.currentUser?.uid;
                    return _MessageBubble(message: message, isMe: isMe);
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 250, 235),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.withAlpha(20),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: const TextStyle(
                      color: Color.fromARGB(120, 70, 40, 20),
                    ),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 240, 228, 185),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  style:
                      const TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 110, 60, 60),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color.fromARGB(255, 200, 180, 150),
              backgroundImage: message.avatarUrl.isNotEmpty
                  ? NetworkImage(message.avatarUrl)
                  : null,
              child: message.avatarUrl.isEmpty
                  ? Text(
                      message.displayName.isNotEmpty
                          ? message.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color.fromARGB(255, 110, 60, 60),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color.fromARGB(180, 70, 40, 20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color.fromARGB(255, 110, 60, 60)
                        : const Color.fromARGB(220, 255, 250, 235),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.withAlpha(20),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe
                          ? Colors.white
                          : const Color.fromARGB(255, 70, 40, 20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color.fromARGB(120, 70, 40, 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ─── MembersSheet ──────────────────────────────────────────────────────────────

class _MembersSheet extends StatelessWidget {
  final Club club;
  const _MembersSheet({required this.club});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color.fromARGB(100, 110, 60, 60),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Members',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 70, 40, 20),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
                if (a.role == ClubRole.owner) return -1;
                if (b.role == ClubRole.owner) return 1;
                return 0;
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isMe =
                      member.uid == FirebaseAuth.instance.currentUser?.uid;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(member.uid)
                        .get(),
                    builder: (context, profileSnapshot) {
                      String displayName = isMe ? 'You' : 'Loading...';
                      String avatarUrl = '';

                      if (profileSnapshot.hasData &&
                          profileSnapshot.data!.exists) {
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
                            backgroundColor: member.role == ClubRole.owner
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
                                      color: member.role == ClubRole.owner
                                          ? Colors.white
                                          : const Color.fromARGB(
                                              255, 110, 60, 60),
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
                            member.role == ClubRole.owner ? 'Owner' : 'Member',
                            style: TextStyle(
                              fontSize: 12,
                              color: member.role == ClubRole.owner
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
          ),
        ),
      ],
    );
  }
}

// ─── Current Book Card ─────────────────────────────────────────────────────

class _CurrentBookCard extends StatelessWidget {
  final Club club;
  final bool isOwner;
  const _CurrentBookCard({required this.club, required this.isOwner});

  void _openPicker(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BookSearchScreen(
        clubId: club.id,
        onBookSelected: (result) async {
          // Show loading while fetching/storing the cover
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
            final user = FirebaseAuth.instance.currentUser!;
            final token = await user.getIdToken();
            const coverUrl =
                'https://us-central1-thebookwasbetter-d4381.cloudfunctions.net/fetchAndStoreCover';
            final coverResponse = await http.post(
              Uri.parse(coverUrl),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'googleBooksId': result.googleBooksId}),
            );

            String resolvedCoverUrl = result.coverUrl;
            if (coverResponse.statusCode == 200) {
              final data =
                  jsonDecode(coverResponse.body) as Map<String, dynamic>;
              resolvedCoverUrl =
                  data['coverUrl'] as String? ?? result.coverUrl;
            }

            final updatedResult = BookSearchResult(
              googleBooksId: result.googleBooksId,
              title: result.title,
              author: result.author,
              coverUrl: resolvedCoverUrl,
              description: result.description,
              categories: result.categories,
            );

            await context.read<StateModel>().selectActiveBook(
                  clubId: club.id,
                  book: updatedResult,
                );

            if (context.mounted) {
              Navigator.of(context).pop(); // dismiss loading
              Navigator.of(context).pop(); // back from search
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.of(context).pop(); // dismiss loading
            }
          }
        },
      ),
    ),
  );
}

  Future<void> _startElection(BuildContext context) async {
    final now = DateTime.now();
    final votingDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'When should voting happen?',
    );
    if (votingDate == null) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: 'What time should voting close?',
    );
    if (endTime == null) return;

    final votingEndTime = DateTime(
      votingDate.year,
      votingDate.month,
      votingDate.day,
      endTime.hour,
      endTime.minute,
    );

    if (context.mounted) {
      await context.read<StateModel>().startElection(
            clubId: club.id,
            votingDate: votingDate,
            votingEndTime: votingEndTime,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (club.activeBookId == null) {
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
                const Icon(Icons.menu_book,
                    size: 18, color: Color.fromARGB(200, 110, 60, 60)),
                const SizedBox(width: 8),
                const Text(
                  'CURRENT BOOK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color.fromARGB(160, 70, 40, 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'No book selected yet.\nStart a vote to pick one!',
              style: TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
            ),
            if (isOwner && club.activeElectionId == null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openPicker(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pick a Book'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 110, 60, 60),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _startElection(context),
                    icon: const Icon(Icons.how_to_vote, size: 18),
                    label: const Text('Start a Vote'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('library_books')
          .doc(club.activeBookId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final book = data != null ? LibraryBook.fromMap(data) : null;

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: book == null
                    ? Container(
                        width: 50,
                        height: 74,
                        color: const Color.fromARGB(255, 200, 180, 150),
                      )
                    : Image.network(
                        book.coverUrl,
                        width: 50,
                        height: 74,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 74,
                          color: const Color.fromARGB(255, 200, 180, 150),
                          child: const Icon(Icons.menu_book,
                              color: Color.fromARGB(120, 110, 60, 60)),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT BOOK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color.fromARGB(160, 70, 40, 20),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book?.title ?? 'Loading...',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 70, 40, 20),
                      ),
                    ),
                    if (book != null)
                      Text(
                        book.author,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 120, 80, 50),
                        ),
                      ),
                    if (isOwner && club.activeElectionId == null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: () => _openPicker(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Change book'),
                          ),
                          TextButton(
                            onPressed: () => _startElection(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Start a vote for next book'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Election Card ─────────────────────────────────────────────────────────
class _ElectionCard extends StatelessWidget {
  final Club club;
  const _ElectionCard({required this.club});

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
      child: Row(
        children: [
          const Icon(Icons.how_to_vote,
              size: 22, color: Color.fromARGB(200, 110, 60, 60)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'A vote for the next book is in progress.',
              style: TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ElectionScreen(clubId: club.id),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 110, 60, 60),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}
// ─── Placeholder card ─────────────────────────────────────────────────────────

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
                  size: 18, color: const Color.fromARGB(200, 110, 60, 60)),
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
