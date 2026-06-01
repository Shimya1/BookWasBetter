enum JoinRequestStatus { pending, accepted, declined }

class JoinRequest {
  final String uid;
  final JoinRequestStatus status;
  final DateTime requestedAt;

  JoinRequest({
    required this.uid,
    this.status = JoinRequestStatus.pending,
    DateTime? requestedAt,
  }) : requestedAt = requestedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
    };
  }

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    return JoinRequest(
      uid: map['uid'] as String,
      status: JoinRequestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => JoinRequestStatus.pending,
      ),
      requestedAt: DateTime.parse(map['requestedAt'] as String),
    );
  }
}