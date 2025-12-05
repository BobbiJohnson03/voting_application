import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import '../repositories/voting_repository.dart';
import '../repositories/ticket_repository.dart';
import '../repositories/vote_repository.dart';
import '../repositories/question_repository.dart';
import '../repositories/signing_key_repository.dart';
import '../repositories/audit_log_repository.dart';
import '../models/secure_vote.dart';
import '../models/question.dart';
import '../models/audit_log.dart';
import '../models/enums.dart';
import 'broadcast_manager.dart';
import 'logic_helpers.dart';

class LogicVote {
  final VotingRepository votings;
  final TicketRepository tickets;
  final VoteRepository votes;
  final QuestionRepository questions;
  final SigningKeyRepository signingKeys;
  final AuditLogRepository auditLogs;
  final BroadcastManager broadcast;
  final Uuid _uuid = Uuid();

  LogicVote({
    required this.votings,
    required this.tickets,
    required this.votes,
    required this.questions,
    required this.signingKeys,
    required this.auditLogs,
    required this.broadcast,
  });

  Future<Response> submitVote(Request req) async {
    final body = await readJson(req);
    final ticketId = body['ticketId'] as String?;
    final sessionId = body['sessionId'] as String?;
    final questionId = body['questionId'] as String?;
    final deviceFingerprint = body['deviceFingerprint'] as String?;
    final selectedOptions =
        (body['selectedOptionIds'] as List?)?.cast<String>() ?? [];

    // ===== VALIDATION =====
    if (ticketId == null || sessionId == null || questionId == null) {
      return jsonErr('Missing required fields');
    }

    final voting = await votings.get(sessionId);
    final ticket = await tickets.get(ticketId);
    final question = await questions.get(questionId);

    if (voting == null) return jsonErr('Voting not found');
    if (ticket == null) return jsonErr('Invalid ticket');
    if (question == null) return jsonErr('Question not found');
    if (!voting.canVote) return jsonErr('Voting closed');
    if (!ticket.isValid) return jsonErr('Ticket expired or already used');

    // ===== SECURITY FIX #1: Device Fingerprint Validation =====
    // Verify that the device submitting the vote matches the ticket's bound device
    if (deviceFingerprint == null || deviceFingerprint.isEmpty) {
      return jsonErr('Device fingerprint required');
    }
    if (ticket.deviceFingerprint != deviceFingerprint) {
      // Log security violation attempt
      await _logSecurityViolation(
        sessionId: sessionId,
        ticketId: ticketId,
        reason: 'Device fingerprint mismatch',
        providedFingerprint: deviceFingerprint,
      );
      return jsonErr(
        'Device mismatch - ticket bound to another device',
        status: 403,
      );
    }

    // Validate ticket belongs to this session
    if (ticket.sessionId != sessionId) {
      return jsonErr('Ticket not valid for this session');
    }

    if (!_isValidSelection(selectedOptions, question)) {
      return jsonErr('Invalid option selection');
    }

    // Get signing key for session
    final sessionKeys = await signingKeys.forSession(sessionId);
    final signingKey = sessionKeys.isNotEmpty ? sessionKeys.first : null;
    if (signingKey == null) return jsonErr('Session configuration error');

    // Check for duplicate vote on THIS QUESTION (not just ticket)
    // A ticket can vote on multiple questions, but only once per question
    final hasVotedOnQuestion = await votes.existsByTicketAndQuestion(
      ticketId,
      questionId,
    );
    if (hasVotedOnQuestion) return jsonErr('Already voted on this question');

    // ===== SECURITY FIX #3: Hash Chain Integrity Verification =====
    // Get previous vote for hash chain and verify chain integrity
    final previousVote = await votes.getLastVoteForSession(sessionId);
    final previousHash = previousVote?.voteHash ?? '0';

    // Verify previous vote integrity if exists
    if (previousVote != null) {
      if (!previousVote.isIntegrityValid) {
        return jsonErr(
          'Vote chain integrity compromised - contact administrator',
        );
      }
      if (!previousVote.validateSignature(signingKey.secret)) {
        return jsonErr('Vote chain signature invalid - contact administrator');
      }
    }

    // Create secure vote
    final vote = SecureVote(
      id: _uuid.v4(),
      sessionId: sessionId,
      questionId: questionId,
      selectedOptionIds: selectedOptions,
      submittedAt: DateTime.now().toUtc(),
      ticketId: ticketId,
      previousVoteHash: previousHash,
      voteHash: '', // Will be computed
      nonce: _uuid.v4(),
      signature: '', // Will be computed
    );

    // Compute hash and signature
    final computedHash = vote.computeHash();
    final signature = SecureVote.generateHMAC(signingKey.secret, computedHash);

    // Create final vote with computed values
    final finalVote = SecureVote(
      id: vote.id,
      sessionId: vote.sessionId,
      questionId: vote.questionId,
      selectedOptionIds: vote.selectedOptionIds,
      submittedAt: vote.submittedAt,
      ticketId: vote.ticketId,
      previousVoteHash: vote.previousVoteHash,
      voteHash: computedHash,
      nonce: vote.nonce,
      signature: signature,
    );

    // Validate signature before saving
    if (!finalVote.validateSignature(signingKey.secret)) {
      return jsonErr('Vote security validation failed');
    }

    // Validate hash integrity
    if (!finalVote.isIntegrityValid) {
      return jsonErr('Vote hash integrity check failed');
    }

    // Save vote
    await votes.put(finalVote);

    // Update voting ledger head
    voting.ledgerHeadHash = finalVote.voteHash;
    await voting.save();

    // ===== SECURITY FIX #2: Mark Ticket as Used =====
    // Check if all questions in session have been answered by this ticket
    final allQuestionIds = voting.questionIds;
    final votedQuestionIds = await _getVotedQuestionIds(ticketId, sessionId);
    votedQuestionIds.add(questionId); // Include current vote

    if (votedQuestionIds.length >= allQuestionIds.length) {
      // All questions answered - mark ticket as fully used
      await tickets.markAsUsed(ticketId);
    }

    // ===== SECURITY FIX #4: Audit Logging =====
    await _logVoteSubmission(
      sessionId: sessionId,
      questionId: questionId,
      voteId: finalVote.id,
      ticketId: ticketId,
      deviceFingerprint: deviceFingerprint,
      meetingId: voting.meetingId,
    );

    broadcast.send(voting.meetingId, {
      'type': 'vote_received',
      'sessionId': sessionId,
      'questionId': questionId,
      'voteId': finalVote.id,
    });

    return jsonOk({
      'success': true,
      'voteId': finalVote.id,
      'message': 'Vote submitted successfully',
    });
  }

  bool _isValidSelection(List<String> selected, Question question) {
    if (selected.isEmpty) return false;
    if (selected.length > question.maxSelections) return false;

    final validOptionIds = question.options.map((o) => o.id).toSet();
    return selected.every((id) => validOptionIds.contains(id));
  }

  /// Get list of question IDs already voted on by this ticket
  Future<Set<String>> _getVotedQuestionIds(
    String ticketId,
    String sessionId,
  ) async {
    final allVotes = await votes.forSession(sessionId);
    return allVotes
        .where((v) => v.ticketId == ticketId)
        .map((v) => v.questionId)
        .toSet();
  }

  /// Log vote submission for audit trail
  Future<void> _logVoteSubmission({
    required String sessionId,
    required String questionId,
    required String voteId,
    required String ticketId,
    required String deviceFingerprint,
    required String meetingId,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      action: AuditAction.voteSubmitted,
      sessionId: sessionId,
      timestamp: DateTime.now().toUtc(),
      userHash: deviceFingerprint,
      details: 'questionId:$questionId,voteId:$voteId',
      previousHash: '', // Will be computed
      hash: '', // Will be computed
      meetingId: meetingId,
    );

    // Compute audit log hash chain
    final lastLog = await auditLogs.getLastLog();
    final previousHash = lastLog?.hash ?? '0';
    auditLog.previousHash = previousHash;
    auditLog.hash = auditLog.computeHash();

    await auditLogs.insert(auditLog);
  }

  /// Log security violation attempts
  Future<void> _logSecurityViolation({
    required String sessionId,
    required String ticketId,
    required String reason,
    required String providedFingerprint,
  }) async {
    final voting = await votings.get(sessionId);
    final auditLog = AuditLog(
      id: _uuid.v4(),
      action: AuditAction.securityViolation,
      sessionId: sessionId,
      timestamp: DateTime.now().toUtc(),
      userHash: providedFingerprint,
      details: 'SECURITY_VIOLATION:$reason,ticketId:$ticketId',
      previousHash: '',
      hash: '',
      meetingId: voting?.meetingId ?? 'unknown',
    );

    final lastLog = await auditLogs.getLastLog();
    auditLog.previousHash = lastLog?.hash ?? '0';
    auditLog.hash = auditLog.computeHash();

    await auditLogs.insert(auditLog);
  }
}
