import 'dart:collection';
import 'package:app/models/note_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StateModel extends ChangeNotifier {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  List<Note> _notes = [];
  StateModel({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    listenToNotes();
  }

   UnmodifiableListView<Note> get notes => UnmodifiableListView(_notes);

    void listenToNotes() {
    final uid = _auth.currentUser!.uid;
    _db
        .collection('Notes')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
          _notes = snapshot.docs
              .map((doc) => Note.fromMap(doc.id, doc.data()))
              .toList();
          notifyListeners();
        });
  }


    Future<void> addRequest(Note request) async {
    await _db.collection('Notes').doc(request.id).set(request.toMap());
  }
}