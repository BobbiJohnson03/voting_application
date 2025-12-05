import 'package:hive/hive.dart';
import '../models/secure_vote.dart'; // ✅ Changed from vote.dart
import '../_boxes.dart';

class VoteRepository {
  Box<SecureVote>? _box;
  Box<String>? _idxByTicketQuestion; // Index by ticketId+questionId

  Future<Box<SecureVote>> _open() async =>
      _box ??= await Hive.openBox<SecureVote>(boxVote);

  Future<Box<String>> _openIdx() async => _idxByTicketQuestion ??=
      await Hive.openBox<String>('idx_vote_byTicketQuestion');

  String _composeKey(String ticketId, String questionId) =>
      '$ticketId|$questionId';

  Future<void> put(SecureVote vote) async {
    final box = await _open();
    final idx = await _openIdx();

    // Check for duplicate votes by ticket+question
    final key = _composeKey(vote.ticketId, vote.questionId);
    if (idx.get(key) != null) {
      throw StateError(
        'Vote already exists for this ticket on question ${vote.questionId}',
      );
    }

    await box.put(vote.id, vote);
    await idx.put(key, vote.id);
  }

  /// Check if ticket already voted on a specific question
  Future<bool> existsByTicketAndQuestion(
    String ticketId,
    String questionId,
  ) async {
    final idx = await _openIdx();
    return idx.get(_composeKey(ticketId, questionId)) != null;
  }

  Future<bool> existsByTicketId(String ticketId) async {
    final box = await _open();
    return box.values.any((v) => v.ticketId == ticketId);
  }

  Future<List<SecureVote>> forSession(String sessionId) async {
    final box = await _open();
    return box.values
        .where((v) => v.sessionId == sessionId)
        .toList(growable: false);
  }

  Future<List<SecureVote>> forSessionAndQuestion(
    String sessionId,
    String questionId,
  ) async {
    final box = await _open();
    return box.values
        .where((v) => v.sessionId == sessionId && v.questionId == questionId)
        .toList(growable: false);
  }

  Future<SecureVote?> getLastVoteForSession(String sessionId) async {
    final votes = await forSession(sessionId);
    if (votes.isEmpty) return null;

    votes.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return votes.first;
  }

  bool validateVoteSignature(SecureVote vote, String secretKey) {
    return vote.validateSignature(secretKey);
  }
}
