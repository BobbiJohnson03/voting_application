import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import '../data/repositories/meeting_repository.dart';
import '../data/repositories/voting_repository.dart';
import '../data/repositories/vote_repository.dart';
import '../data/repositories/question_repository.dart';
import '../data/repositories/audit_log_repository.dart';
import '../data/models/secure_vote.dart';
import '../data/models/audit_log.dart';
import '../data/models/enums.dart';
import 'broadcast_manager.dart';
import 'logic_helpers.dart';

class LogicAdmin {
  final MeetingRepository meetings;
  final VotingRepository votings;
  final VoteRepository votes;
  final QuestionRepository questions;
  final AuditLogRepository auditLogs;
  final BroadcastManager broadcast;
  final Uuid _uuid = Uuid();

  LogicAdmin({
    required this.meetings,
    required this.votings,
    required this.votes,
    required this.questions,
    required this.auditLogs,
    required this.broadcast,
  });

  Future<Response> results(Request req) async {
    final sessionId = req.url.queryParameters['sessionId'];
    if (sessionId == null) return _errorResponse('Missing sessionId');

    final voting = await votings.get(sessionId);
    if (voting == null) return _errorResponse('Voting not found');

    final votingVotes = await votes.forSession(sessionId);
    final results = await _calculateResults(votingVotes);

    // Include vote count and chain status
    return _successResponse({
      'results': results,
      'totalVotes': votingVotes.length,
      'sessionStatus': voting.status.name,
    });
  }

  Future<Response> closeSession(Request req) async {
    final body = await readJson(req);
    final sessionId = body['sessionId'] as String?;

    if (sessionId == null) return _errorResponse('Missing sessionId');

    final voting = await votings.get(sessionId);
    if (voting == null) return _errorResponse('Voting not found');

    voting.close();

    // ===== AUDIT LOGGING =====
    await _logVotingClosed(meetingId: voting.meetingId, sessionId: sessionId);

    broadcast.send(voting.meetingId, {
      'type': 'voting_closed',
      'sessionId': sessionId,
    });

    return _successResponse({'message': 'Voting closed'});
  }

  Future<Map<String, dynamic>> _calculateResults(List<SecureVote> votes) async {
    final Map<String, Map<String, int>> tallies = {};

    for (final vote in votes) {
      final questionTallies = tallies.putIfAbsent(
        vote.questionId,
        () => <String, int>{},
      );

      for (final optionId in vote.selectedOptionIds) {
        questionTallies[optionId] = (questionTallies[optionId] ?? 0) + 1;
      }
    }

    return tallies;
  }

  Response _successResponse(Map<String, dynamic> data) {
    return Response.ok(
      jsonEncode({'success': true, ...data}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _errorResponse(String message, {int status = 400}) {
    return Response(
      status,
      body: jsonEncode({'success': false, 'error': message}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ===== AUDIT LOGGING =====

  Future<void> _logVotingClosed({
    required String meetingId,
    required String sessionId,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      action: AuditAction.votingClosed,
      sessionId: sessionId,
      timestamp: DateTime.now().toUtc(),
      userHash: 'ADMIN',
      details: 'Session closed by admin',
      previousHash: '',
      hash: '',
      meetingId: meetingId,
    );

    final lastLog = await auditLogs.getLastLog();
    auditLog.previousHash = lastLog?.hash ?? '0';
    auditLog.hash = auditLog.computeHash();

    await auditLogs.insert(auditLog);
  }
}
