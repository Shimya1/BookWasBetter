import 'package:uuid/uuid.dart';

class Election {
  final String id;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime votingDate;
  final DateTime votingEndTime;
  final List<String> eligibleVoterUids;
  final String? winningBookId;
  final List<String>? tiedBookIds;
  final DateTime? closedAt;

  Election({
    String? id,
    required this.createdByUid,
    DateTime? createdAt,
    required this.votingDate,
    required this.votingEndTime,
    required this.eligibleVoterUids,
    this.winningBookId,
    this.tiedBookIds,
    this.closedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // Nominations close at midnight on votingDate — "a day before" voting,
  // whatever gap the owner picked when creating the election.
  DateTime get nominationsCloseAt =>
      DateTime(votingDate.year, votingDate.month, votingDate.day);

  bool get isClosed => closedAt != null;
  bool get isTied => tiedBookIds != null && !isClosed;
  bool get isVoting =>
      !isClosed && !isTied && DateTime.now().isAfter(nominationsCloseAt);
  bool get isNominating =>
      !isClosed && !isTied && DateTime.now().isBefore(nominationsCloseAt);

  Map<String, dynamic> toMap() => {
        'createdByUid': createdByUid,
        'createdAt': createdAt.toIso8601String(),
        'votingDate': votingDate.toUtc().toIso8601String(),
        'votingEndTime': votingEndTime.toUtc().toIso8601String(),
        'eligibleVoterUids': eligibleVoterUids,
        'winningBookId': winningBookId,
        'tiedBookIds': tiedBookIds,
        'closedAt': closedAt?.toIso8601String(),
      };

  factory Election.fromMap(String id, Map<String, dynamic> map) => Election(
        id: id,
        createdByUid: map['createdByUid'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        votingDate: DateTime.parse(map['votingDate'] as String).toLocal(),
        votingEndTime: DateTime.parse(map['votingEndTime'] as String).toLocal(),
        eligibleVoterUids: List<String>.from(map['eligibleVoterUids'] ?? []),
        winningBookId: map['winningBookId'] as String?,
        tiedBookIds: map['tiedBookIds'] != null
            ? List<String>.from(map['tiedBookIds'])
            : null,
        closedAt: map['closedAt'] != null
            ? DateTime.parse(map['closedAt'] as String)
            : null,
      );
}

class Nomination {
  final String uid;
  final String googleBooksId;
  final String title;
  final String author;
  final String coverUrl;
  final DateTime submittedAt;

  Nomination({
    required this.uid,
    required this.googleBooksId,
    required this.title,
    required this.author,
    required this.coverUrl,
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'googleBooksId': googleBooksId,
        'title': title,
        'author': author,
        'coverUrl': coverUrl,
        'submittedAt': submittedAt.toIso8601String(),
      };

  factory Nomination.fromMap(Map<String, dynamic> map) => Nomination(
        uid: map['uid'] as String,
        googleBooksId: map['googleBooksId'] as String,
        title: map['title'] as String,
        author: map['author'] as String,
        coverUrl: map['coverUrl'] as String,
        submittedAt: DateTime.parse(map['submittedAt'] as String),
      );
}

class Vote {
  final String uid;
  final String googleBooksId;
  final DateTime votedAt;

  Vote({
    required this.uid,
    required this.googleBooksId,
    DateTime? votedAt,
  }) : votedAt = votedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'googleBooksId': googleBooksId,
        'votedAt': votedAt.toIso8601String(),
      };

  factory Vote.fromMap(Map<String, dynamic> map) => Vote(
        uid: map['uid'] as String,
        googleBooksId: map['googleBooksId'] as String,
        votedAt: DateTime.parse(map['votedAt'] as String),
      );
}