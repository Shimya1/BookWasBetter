import 'dart:collection';
import 'package:app/models/book_model.dart';
import 'package:app/models/club_member_model.dart';
import 'package:app/models/club_model.dart';
import 'package:app/models/join_request_model.dart';
import 'package:app/models/note_model.dart';
import 'package:app/models/user_profile_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';


class StateModel extends ChangeNotifier {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  List<Note> _notes = [];
  List<Book> _books = [];
  List<Club> _clubs = [];
  UserProfile? _profile;
  
    
  

  StateModel({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    // Listen for auth state so we start listeners safely after login
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToNotes(user.uid);
        _listenToBooks(user.uid);
        _listenToProfile(user.uid);
        _listenToClubs(user.uid);
      } else {
        _notes = [];
        _books = [];
        _clubs = [];
        _profile = null;
        notifyListeners();
      }
    });
  }

  UnmodifiableListView<Note> get notes => UnmodifiableListView(_notes);
  UnmodifiableListView<Book> get books => UnmodifiableListView(_books);
  UnmodifiableListView<Club> get clubs => UnmodifiableListView(_clubs);
  UserProfile? get profile => _profile;
  // ─── Filtered book views ────────────────────────────────────────────────────

  List<Book> get currentlyReading =>
      _books.where((b) => b.status == BookStatus.currentlyReading).toList();

  List<Book> get wantToRead =>
      _books.where((b) => b.status == BookStatus.wantToRead).toList();

  List<Book> get finishedBooks =>
      _books.where((b) => b.status == BookStatus.finished).toList();

  List<Book> get abandonedBooks =>
      _books.where((b) => b.status == BookStatus.abandoned).toList();

  // ─── Notes ──────────────────────────────────────────────────────────────────

  void _listenToNotes(String uid) {
    _db
        .collection('Notes')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      _notes =
          snapshot.docs.map((doc) => Note.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> addNote(Note note) async {
    await _db.collection('Notes').doc(note.id).set(note.toMap());
  }

  // ─── Books ───────────────────────────────────────────────────────────────────

  void _listenToBooks(String uid) {
    _db
        .collection('books')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      _books =
          snapshot.docs.map((doc) => Book.fromMap(doc.id, doc.data())).toList();
      // Sort: currently reading first, then most recently added
      _books.sort((a, b) {
        if (a.status == BookStatus.currentlyReading &&
            b.status != BookStatus.currentlyReading) return -1;
        if (b.status == BookStatus.currentlyReading &&
            a.status != BookStatus.currentlyReading) return 1;
        return b.dateAdded.compareTo(a.dateAdded);
      });
      notifyListeners();
    });
  }

  Future<void> addBook(Book book) async {
    await _db.collection('books').doc(book.id).set(book.toMap());
  }

  Future<void> updateBookStatus(String bookId, BookStatus newStatus) async {
    final update = <String, dynamic>{'status': newStatus.firestoreValue};
    if (newStatus == BookStatus.finished || newStatus == BookStatus.abandoned) {
      update['dateFinished'] = DateTime.now().toIso8601String();
    }
    await _db.collection('books').doc(bookId).update(update);
  }

  Future<void> updateBookChapter(String bookId, int chapter) async {
    await _db
        .collection('books')
        .doc(bookId)
        .update({'currentChapter': chapter});
  }

  Future<void> deleteBook(String bookId) async {
    await _db.collection('books').doc(bookId).delete();
  }

  // ─── Clubs ───────────────────────────────────────────────────────────────────



  void _listenToClubs(String uid) {
    _db
        .collection('clubs')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
      _clubs =
          snapshot.docs.map((doc) => Club.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> createClub(String name) async {
    final uid = _auth.currentUser!.uid;
    final club = Club(name: name, founderUid: uid);

    // Create the club document
    await _db.collection('clubs').doc(club.id).set({
      ...club.toMap(),
      'memberUids': [uid], // array for easy querying
    });

    // Add founder to members subcollection
    final member = ClubMember(uid: uid, role: ClubRole.founder);
    await _db
        .collection('clubs')
        .doc(club.id)
        .collection('members')
        .doc(uid)
        .set(member.toMap());
  }

  Future<void> sendJoinRequest(String inviteCode) async {
    final uid = _auth.currentUser!.uid;

    // Find the club with this invite code
    final query = await _db
        .collection('clubs')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No club found with that invite code.');
    }

    final clubId = query.docs.first.id;

    // Check if already a member
    final memberDoc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(uid)
        .get();

    if (memberDoc.exists) {
      throw Exception('You are already a member of this club.');
    }

    // Write the join request
    final request = JoinRequest(uid: uid);
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('joinRequests')
        .doc(uid)
        .set(request.toMap());
  }

  Future<void> respondToJoinRequest({
    required String clubId,
    required String requestUid,
    required bool accept,
  }) async {
    if (accept) {
      // Add to members subcollection and memberUids array
      final member = ClubMember(uid: requestUid, role: ClubRole.member);
      await _db
          .collection('clubs')
          .doc(clubId)
          .collection('members')
          .doc(requestUid)
          .set(member.toMap());

      await _db.collection('clubs').doc(clubId).update({
        'memberUids': FieldValue.arrayUnion([requestUid]),
      });
    }

    // Update request status either way
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('joinRequests')
        .doc(requestUid)
        .update({'status': accept ? 'accepted' : 'declined'});
  }

// ─── Profile ─────────────────────────────────────────────────────────────────

  void _listenToProfile(String uid) {
    _db.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists) {
        _profile = UserProfile.fromMap(doc.data()!);
      } else {
        // First login — create an empty profile document
        final newProfile = UserProfile(uid: uid, displayName: '');
        _db.collection('users').doc(uid).set(newProfile.toMap());
        _profile = newProfile;
      }
      notifyListeners();
    });
  }

  Future<void> updateDisplayName(String displayName) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid).update({'displayName': displayName});
  }

  Future<void> updateAvatarUrl(String avatarUrl) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid).update({'avatarUrl': avatarUrl});
  }
}
