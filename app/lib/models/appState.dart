import 'dart:collection';
import 'package:app/models/activity_model.dart';
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
import 'package:app/models/election_model.dart';
import 'package:app/models/club_library_model.dart';

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

    // 1. Remove tag from profile
    final updatedTags =
        _profile?.tags.where((t) => t.id != tagId).toList() ?? [];
    await _db.collection('users').doc(uid).update({
      'tags': updatedTags.map((t) => t.toMap()).toList(),
    });

    // 2. Remove tagId from all notes that contain it
    final notesSnapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .where('tagIds', arrayContains: tagId)
        .get();

    final batch = _db.batch();
    for (final doc in notesSnapshot.docs) {
      batch.update(doc.reference, {
        'tagIds': FieldValue.arrayRemove([tagId]),
      });
    }
    await batch.commit();
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

  // user book rating
  Future<void> updateBookRating(String bookId, double rating) async {
    final uid = _auth.currentUser!.uid;
    await _db
        .collection('users')
        .doc(uid)
        .collection('books')
        .doc(bookId)
        .update({'rating': rating});
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
        'categories': result.categories,
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
  final uid = _auth.currentUser!.uid;
  final update = <String, dynamic>{'status': newStatus.firestoreValue};
  if (newStatus == BookStatus.finished || newStatus == BookStatus.abandoned) {
    update['dateFinished'] = DateTime.now().toIso8601String();
  }
  await _db
      .collection('users')
      .doc(uid)
      .collection('books')
      .doc(bookId)
      .update(update);
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
    final club = Club(name: name, ownerUid: uid);

    // Create the club document
    await _db.collection('clubs').doc(club.id).set({
      ...club.toMap(),
      'memberUids': [uid], // array for easy querying
    });

    // Add owner to members subcollection
    final member = ClubMember(uid: uid, role: ClubRole.owner);
    await _db
        .collection('clubs')
        .doc(club.id)
        .collection('members')
        .doc(uid)
        .set(member.toMap());

    await _db.collection('users').doc(uid).update({
      'memberClubIds': FieldValue.arrayUnion([club.id]),
    });

    try {
      await _writeActivity(
        clubId: club.id,
        entry: ActivityEntry(
          type: ActivityType.clubCreated,
          actorUid: uid,
          actorName: uid == _profile?.uid && _profile!.displayName.isNotEmpty
              ? _profile!.displayName
              : 'A member',
        ),
      );
    } catch (e) {
      debugPrint('Activity write failed: $e');
    }
  }


Future<void> deleteClub(String clubId) async {
  final uid = _auth.currentUser!.uid;

  // Fetch all subcollection docs to delete
  final members = await _db.collection('clubs').doc(clubId).collection('members').get();
  final activity = await _db.collection('clubs').doc(clubId).collection('activity').get();
  final joinRequests = await _db.collection('clubs').doc(clubId).collection('joinRequests').get();

  final batch = _db.batch();

  for (final doc in members.docs) batch.delete(doc.reference);
  for (final doc in activity.docs) batch.delete(doc.reference);
  for (final doc in joinRequests.docs) batch.delete(doc.reference);

  batch.delete(_db.collection('clubs').doc(clubId));

  await batch.commit();

  await _db.collection('users').doc(uid).update({
    'memberClubIds': FieldValue.arrayRemove([clubId]),
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
      // Fetch the joiner's display name
      final userDoc = await _db.collection('users').doc(requestUid).get();
      final actorName =
          (userDoc.data()?['displayName'] as String? ?? '').isNotEmpty
              ? userDoc.data()!['displayName'] as String
              : 'A new member';

      try {
        await _writeActivity(
          clubId: clubId,
          entry: ActivityEntry(
            type: ActivityType.memberJoined,
            actorUid: requestUid,
            actorName: actorName,
          ),
        );
      } catch (e) {
        debugPrint('Activity write failed: $e');
      }
    }
    // Update request status either way
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('joinRequests')
        .doc(requestUid)
        .update({'status': accept ? 'accepted' : 'declined'});
  }

  Future<void> _writeActivity({
    required String clubId,
    required ActivityEntry entry,
  }) async {
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('activity')
        .doc(entry.id)
        .set(entry.toMap());
  }

  Future<void> transferOwnership({
    required String clubId,
    required String newOwnerUid,
  }) async {
    final uid = _auth.currentUser!.uid;

    // Fetch new owner's display name for the activity entry
    final newOwnerDoc = await _db.collection('users').doc(newOwnerUid).get();
    final newOwnerName =
        (newOwnerDoc.data()?['displayName'] as String? ?? '').isNotEmpty
            ? newOwnerDoc.data()!['displayName'] as String
            : 'A member';

    final batch = _db.batch();

    // Update club doc
    batch.update(_db.collection('clubs').doc(clubId), {
      'ownerUid': newOwnerUid,
    });

    // Demote old owner to member
    batch.update(
      _db.collection('clubs').doc(clubId).collection('members').doc(uid),
      {'role': ClubRole.member.name},
    );

    // Promote new owner
    batch.update(
      _db
          .collection('clubs')
          .doc(clubId)
          .collection('members')
          .doc(newOwnerUid),
      {'role': ClubRole.owner.name},
    );

    await batch.commit();

    

    try {
      await _writeActivity(
        clubId: clubId,
        entry: ActivityEntry(
          type: ActivityType.ownershipTransferred,
          actorUid: uid,
          actorName: _profile?.displayName ?? 'A member',
          targetName: newOwnerName,
        ),
      );
    } catch (e) {
      debugPrint('Activity write failed: $e');
    }
  }
  Future<void> _rolloverLibraryEntry({
    required WriteBatch batch,
    required String clubId,
    required String googleBooksId,
    required String title,
    required String author,
    required String coverUrl,
    required BookSelectionMethod method,
    String? selectedByUid,
    String? selectedByName,
  }) async {
    final libraryRef =
        _db.collection('clubs').doc(clubId).collection('libraryBooks');

    final openEntry =
        await libraryRef.where('finishedAt', isNull: true).limit(1).get();
    if (openEntry.docs.isNotEmpty) {
      batch.update(openEntry.docs.first.reference, {
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }

    final entry = ClubLibraryEntry(
      googleBooksId: googleBooksId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      selectionMethod: method,
      selectedByUid: selectedByUid,
      selectedByName: selectedByName,
    );
    batch.set(libraryRef.doc(entry.id), entry.toMap());
  }

  Future<void> selectActiveBook({
    required String clubId,
    required BookSearchResult book,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _db.batch();

    final libraryBookRef =
        _db.collection('library_books').doc(book.googleBooksId);
    batch.set(
      libraryBookRef,
      {
        'googleBooksId': book.googleBooksId,
        'title': book.title,
        'author': book.author,
        'coverUrl': book.coverUrl,
        'description': book.description,
        'categories': book.categories,
      },
      SetOptions(merge: true),
    );

    batch.update(_db.collection('clubs').doc(clubId), {
      'activeBookId': book.googleBooksId,
    });

        await _rolloverLibraryEntry(
      batch: batch,
      clubId: clubId,
      googleBooksId: book.googleBooksId,
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
      method: BookSelectionMethod.owner,
      selectedByUid: uid,
      selectedByName: _profile?.displayName,
    );

    await batch.commit();

    try {
      await _writeActivity(
        clubId: clubId,
        entry: ActivityEntry(
          type: ActivityType.bookSelected,
          actorUid: uid,
          actorName: _profile?.displayName ?? 'A member',
          targetName: book.title,
        ),
      );
    } catch (e) {
      debugPrint('Activity write failed: $e');
    }
  }

  Future<void> startElection({
    required String clubId,
    required DateTime votingDate,
    required DateTime votingEndTime,
  }) async {
    final uid = _auth.currentUser!.uid;
    final club = _clubs.firstWhere((c) => c.id == clubId);

    final election = Election(
      createdByUid: uid,
      votingDate: votingDate,
      votingEndTime: votingEndTime,
      eligibleVoterUids: club.memberUids,
    );

    final batch = _db.batch();
    final electionRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('elections')
        .doc(election.id);
    batch.set(electionRef, election.toMap());
    batch.update(_db.collection('clubs').doc(clubId), {
      'activeElectionId': election.id,
    });
    await batch.commit();

    try {
      await _writeActivity(
        clubId: clubId,
        entry: ActivityEntry(
          type: ActivityType.electionStarted,
          actorUid: uid,
          actorName: _profile?.displayName ?? 'A member',
        ),
      );
    } catch (e) {
      debugPrint('Activity write failed: $e');
    }
  }

  Future<void> submitNomination({
    required String clubId,
    required String electionId,
    required BookSearchResult book,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _db.batch();

    final libraryBookRef =
        _db.collection('library_books').doc(book.googleBooksId);
    batch.set(
      libraryBookRef,
      {
        'googleBooksId': book.googleBooksId,
        'title': book.title,
        'author': book.author,
        'coverUrl': book.coverUrl,
        'description': book.description,
        'categories': book.categories,
      },
      SetOptions(merge: true),
    );

    final nomination = Nomination(
      uid: uid,
      googleBooksId: book.googleBooksId,
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
    );
    final nominationRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('elections')
        .doc(electionId)
        .collection('nominations')
        .doc(uid);
    batch.set(nominationRef, nomination.toMap());

    await batch.commit();
  }

  Future<void> castVote({
    required String clubId,
    required String electionId,
    required String googleBooksId,
  }) async {
    final uid = _auth.currentUser!.uid;
    final vote = Vote(uid: uid, googleBooksId: googleBooksId);

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('elections')
        .doc(electionId)
        .collection('votes')
        .doc(uid)
        .set(vote.toMap());
  }

  Future<void> resolveTie({
    required String clubId,
    required String electionId,
    required String googleBooksId,
  }) async {
    final uid = _auth.currentUser!.uid;
    final libraryDoc =
        await _db.collection('library_books').doc(googleBooksId).get();
    final libraryData = libraryDoc.data();
    final title = libraryData?['title'] as String? ?? 'the selected book';
    final author = libraryData?['author'] as String? ?? '';
    final coverUrl = libraryData?['coverUrl'] as String? ?? '';

    final batch = _db.batch();
    batch.update(
      _db
          .collection('clubs')
          .doc(clubId)
          .collection('elections')
          .doc(electionId),
      {
        'winningBookId': googleBooksId,
        'closedAt': DateTime.now().toIso8601String(),
      },
    );
    batch.update(_db.collection('clubs').doc(clubId), {
      'activeBookId': googleBooksId,
      'activeElectionId': null,
    });

    await _rolloverLibraryEntry(
      batch: batch,
      clubId: clubId,
      googleBooksId: googleBooksId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      method: BookSelectionMethod.election,
    );

    await batch.commit();

    try {
      await _writeActivity(
        clubId: clubId,
        entry: ActivityEntry(
          type: ActivityType.bookSelected,
          actorUid: uid,
          actorName: _profile?.displayName ?? 'A member',
          targetName: title,
        ),
      );
    } catch (e) {
      debugPrint('Activity write failed: $e');
    }
  }

  Future<void> updateElectionVotingDate({
  required String clubId,
  required String electionId,
  required DateTime newVotingDate,
}) async {
  await _db
      .collection('clubs')
      .doc(clubId)
      .collection('elections')
      .doc(electionId)
      .update({'votingDate': newVotingDate.toUtc().toIso8601String()});
}

Future<void> updateElectionVotingEndTime({
  required String clubId,
  required String electionId,
  required DateTime newVotingEndTime,
}) async {
  await _db
      .collection('clubs')
      .doc(clubId)
      .collection('elections')
      .doc(electionId)
      .update({'votingEndTime': newVotingEndTime.toUtc().toIso8601String()});
}

Future<void> deleteElection({
  required String clubId,
  required String electionId,
}) async {
  final electionRef = _db
      .collection('clubs')
      .doc(clubId)
      .collection('elections')
      .doc(electionId);

  final nominations = await electionRef.collection('nominations').get();
  final votes = await electionRef.collection('votes').get();

  final batch = _db.batch();
  for (final doc in nominations.docs) batch.delete(doc.reference);
  for (final doc in votes.docs) batch.delete(doc.reference);
  batch.delete(electionRef);
  batch.update(_db.collection('clubs').doc(clubId), {
    'activeElectionId': null,
  });
  await batch.commit();
}

  Future<void> leaveClub(String clubId) async {
    final uid = _auth.currentUser!.uid;

    await _db.collection('clubs').doc(clubId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
    });

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(uid)
        .delete();

    await _db.collection('users').doc(uid).update({
      'memberClubIds': FieldValue.arrayRemove([clubId]),
    });

    // Delete old join request so they can rejoin later
    try {
      await _db
          .collection('clubs')
          .doc(clubId)
          .collection('joinRequests')
          .doc(uid)
          .delete();
    } catch (_) {}

    try {
      await _writeActivity(
        clubId: clubId,
        entry: ActivityEntry(
          type: ActivityType.memberLeft,
          actorUid: uid,
          actorName: _profile?.displayName ?? 'A member',
        ),
      );
    } catch (e) {
      debugPrint('Activity write failed: $e');
    }
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
