import 'dart:collection';
import 'package:app/models/book_model.dart';
import 'package:app/models/book_view_model.dart';
import 'package:app/models/club_member_model.dart';
import 'package:app/models/club_model.dart';
import 'package:app/models/join_request_model.dart';
import 'package:app/models/library_book_model.dart';
import 'package:app/models/note_model.dart';
import 'package:app/models/tag_model.dart';
import 'package:app/models/user_profile_model.dart';
import 'package:app/services/google_books_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StateModel extends ChangeNotifier {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  List<Note> _notes = [];
  List<BookView> _books = [];
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
  UnmodifiableListView<BookView> get books => UnmodifiableListView(_books);
  UnmodifiableListView<Club> get clubs => UnmodifiableListView(_clubs);
  UserProfile? get profile => _profile;
  // ─── Filtered book views ────────────────────────────────────────────────────

  List<BookView> get currentlyReading =>
      _books.where((b) => b.status == BookStatus.currentlyReading).toList();

  List<BookView> get wantToRead =>
      _books.where((b) => b.status == BookStatus.wantToRead).toList();

  List<BookView> get finishedBooks =>
      _books.where((b) => b.status == BookStatus.finished).toList();

  List<BookView> get abandonedBooks =>
      _books.where((b) => b.status == BookStatus.abandoned).toList();

  // ─── Notes ──────────────────────────────────────────────────────────────────

  void _listenToNotes(String uid) {
    _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notes =
          snapshot.docs.map((doc) => Note.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> createTag(Tag tag) async {
    final uid = _auth.currentUser!.uid;
    final updatedTags = [...?_profile?.tags, tag];
    await _db.collection('users').doc(uid).update({
      'tags': updatedTags.map((t) => t.toMap()).toList(),
    });
  }

  Future<void> deleteTag(String tagId) async {
    final uid = _auth.currentUser!.uid;
    final updatedTags =
        _profile?.tags.where((t) => t.id != tagId).toList() ?? [];
    await _db.collection('users').doc(uid).update({
      'tags': updatedTags.map((t) => t.toMap()).toList(),
    });
  }

  Future<void> addNote(Note note) async {
    await _db
        .collection('users')
        .doc(note.userId)
        .collection('notes')
        .doc(note.id)
        .set(note.toMap());
  }

  Future<void> updateNote(Note note) async {
    await _db
        .collection('users')
        .doc(note.userId)
        .collection('notes')
        .doc(note.id)
        .update(note.toMap());
  }

  Future<void> deleteNote(Note note) async {
    await _db
        .collection('users')
        .doc(note.userId)
        .collection('notes')
        .doc(note.id)
        .delete();
  }
  // ─── Books ───────────────────────────────────────────────────────────────────

  void _listenToBooks(String uid) {
    _db
        .collection('users')
        .doc(uid)
        .collection('books')
        .snapshots()
        .listen((snapshot) async {
      final userBooks =
          snapshot.docs.map((doc) => Book.fromMap(doc.id, doc.data())).toList();

      final libraryBookDocs = await Future.wait(
        userBooks.map((book) =>
            _db.collection('library_books').doc(book.googleBooksId).get()),
      );

      final bookViews = <BookView>[];
      for (int i = 0; i < userBooks.length; i++) {
        final doc = libraryBookDocs[i];
        if (doc.exists) {
          bookViews.add(BookView(
            book: userBooks[i],
            libraryBook: LibraryBook.fromMap(doc.data()!),
          ));
        }
      }

      _books = bookViews;
      notifyListeners();
    });
  }

  Future<void> addBook(BookSearchResult result, BookStatus status) async {
    final uid = _auth.currentUser!.uid;
    final book = Book(
      userId: uid,
      googleBooksId: result.googleBooksId,
      status: status,
    );

    final batch = _db.batch();

    // 1. Create or update the library book
    final libraryBookRef =
        _db.collection('library_books').doc(result.googleBooksId);
    batch.set(
      libraryBookRef,
      {
        'googleBooksId': result.googleBooksId,
        'title': result.title,
        'author': result.author,
        'coverUrl': result.coverUrl,
        'description': result.description,
        'numUsersBorrowing': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    // 2. Create the user book
    final userBookRef =
        _db.collection('users').doc(uid).collection('books').doc(book.id);
    batch.set(userBookRef, book.toMap());

    await batch.commit();
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

  Future<void> deleteBook(String bookId, String googleBooksId) async {
    final uid = _auth.currentUser!.uid;

    final userBookRef =
        _db.collection('users').doc(uid).collection('books').doc(bookId);

    final libraryBookRef = _db.collection('library_books').doc(googleBooksId);

    bool wasLastBorrower = false;

    await _db.runTransaction((transaction) async {
      // 1. Read the library book first
      final libraryBookDoc = await transaction.get(libraryBookRef);

      if (!libraryBookDoc.exists) {
        // Nothing to clean up, just delete the user book
        transaction.delete(userBookRef);
        return;
      }

      final count =
          (libraryBookDoc.data()!['numUsersBorrowing'] as num).toInt();

      // 2. Delete the user book
      transaction.delete(userBookRef);

      if (count <= 1) {
        // 3a. Last borrower — delete the library book entirely
        wasLastBorrower = true;
        transaction.delete(libraryBookRef);
      } else {
        // 3b. Others still have it — just decrement
        transaction.update(libraryBookRef, {
          'numUsersBorrowing': FieldValue.increment(-1),
        });
      }
    });

    // Delete the cover from Storage if no one is using the book anymore
    if (wasLastBorrower) {
      try {
        await FirebaseStorage.instance
            .ref('covers/$googleBooksId.jpg')
            .delete();
      } catch (_) {
        // If the file doesn't exist, ignore
      }
    }
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

    await _db.collection('users').doc(uid).update({
      'memberClubIds': FieldValue.arrayUnion([club.id]),
    });
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

      // Update the user's profile to include the new club
      await _db.collection('users').doc(requestUid).update({
        'memberClubIds': FieldValue.arrayUnion([clubId]),
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
