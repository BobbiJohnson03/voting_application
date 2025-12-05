import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../repositories/meeting_repository.dart';
import '../repositories/voting_repository.dart';
import '../repositories/ticket_repository.dart';
import '../repositories/meeting_pass_repository.dart';
import '../repositories/audit_log_repository.dart';
import '../models/meeting_pass.dart';
import '../models/audit_log.dart';
import '../models/enums.dart';
import 'broadcast_manager.dart';
import 'logic_helpers.dart';
import '../models/voting.dart';

class LogicJoinTicket {
  final MeetingRepository meetings;
  final VotingRepository votings;
  final TicketRepository tickets;
  final MeetingPassRepository meetingPasses;
  final AuditLogRepository auditLogs;
  final BroadcastManager broadcast;
  final Uuid _uuid = Uuid();

  LogicJoinTicket({
    required this.meetings,
    required this.votings,
    required this.tickets,
    required this.meetingPasses,
    required this.auditLogs,
    required this.broadcast,
  });

  Future<Response> joinMeeting(Request req) async {
    final body = await readJson(req);
    var meetingId = body['meetingId'] as String?;
    final joinCode = body['joinCode'] as String?;
    final deviceFingerprint = body['deviceFingerprint'] as String?;

    // ===== INPUT VALIDATION =====
    if (deviceFingerprint == null || deviceFingerprint.isEmpty) {
      return jsonErr('Device fingerprint required');
    }

    // Validate fingerprint format (should be SHA-256 hex string)
    if (!_isValidFingerprint(deviceFingerprint)) {
      return jsonErr('Invalid device fingerprint format');
    }

    // Support joining by code (for web/PWA clients)
    if (meetingId == null && joinCode != null) {
      // Sanitize join code
      final sanitizedCode = _sanitizeInput(joinCode);
      final meeting = await meetings.getByJoinCode(sanitizedCode);
      if (meeting != null) {
        meetingId = meeting.id;
      }
    }

    if (meetingId == null)
      return jsonErr('Missing meetingId or invalid joinCode');

    final meeting = await meetings.get(meetingId);
    if (meeting == null) return jsonErr('Meeting not found');
    if (!meeting.canJoin) return jsonErr('Meeting not available');

    // Check if device already has a pass
    final hasPass = await meetingPasses.hasDevicePass(
      meetingId,
      deviceFingerprint,
    );
    if (hasPass) {
      return jsonErr('Device already joined this meeting');
    }

    // Create meeting pass
    final meetingPass = MeetingPass(
      passId: _uuid.v4(),
      meetingId: meetingId,
      deviceFingerprintHash: deviceFingerprint,
    );

    await meetingPasses.put(meetingPass);

    // ===== AUDIT LOGGING =====
    await _logMeetingJoin(
      meetingId: meetingId,
      meetingPassId: meetingPass.passId,
      deviceFingerprint: deviceFingerprint,
    );

    // Get active sessions
    final activeVotings = await votings.openForMeeting(meetingId);

    return jsonOk({
      'meetingId': meeting.id,
      'meetingPassId': meetingPass.passId,
      'meeting': {
        'id': meeting.id,
        'title': _sanitizeOutput(meeting.title),
        'isActive': meeting.isActive,
      },
      'activeSessions': activeVotings.map((v) => _votingToJson(v)).toList(),
    });
  }

  Future<Response> requestTicket(Request req) async {
    final body = await readJson(req);
    final meetingPassId = body['meetingPassId'] as String?;
    final sessionId = body['sessionId'] as String?;
    final deviceFingerprint = body['deviceFingerprint'] as String?;

    // ===== INPUT VALIDATION =====
    if (meetingPassId == null || sessionId == null) {
      return jsonErr('Missing required fields');
    }

    if (deviceFingerprint == null || deviceFingerprint.isEmpty) {
      return jsonErr('Device fingerprint required');
    }

    if (!_isValidFingerprint(deviceFingerprint)) {
      return jsonErr('Invalid device fingerprint format');
    }

    final voting = await votings.get(sessionId);
    if (voting == null) return jsonErr('Voting not found');
    if (!voting.canVote) return jsonErr('Voting not available');

    final meetingPass = await meetingPasses.get(meetingPassId);
    if (meetingPass == null || meetingPass.revoked) {
      return jsonErr('Invalid meeting pass');
    }

    // ===== SECURITY: Verify device fingerprint matches meeting pass =====
    if (meetingPass.deviceFingerprintHash != deviceFingerprint) {
      // Log security violation
      await _logSecurityViolation(
        meetingId: voting.meetingId,
        sessionId: sessionId,
        reason: 'Meeting pass device mismatch on ticket request',
        deviceFingerprint: deviceFingerprint,
      );
      return jsonErr(
        'Device mismatch - meeting pass bound to another device',
        status: 403,
      );
    }

    // Create ticket
    final ticket = await tickets.create(
      sessionId: sessionId,
      meetingPassId: meetingPassId,
      deviceFingerprint: deviceFingerprint,
    );

    // ===== AUDIT LOGGING =====
    await _logTicketIssued(
      meetingId: voting.meetingId,
      sessionId: sessionId,
      ticketId: ticket.id,
      deviceFingerprint: deviceFingerprint,
    );

    broadcast.send(voting.meetingId, {
      'type': 'ticket_issued',
      'sessionId': sessionId,
      'ticketId': ticket.id,
    });

    return jsonOk({
      'ticketId': ticket.id,
      'sessionId': ticket.sessionId,
      'expiresAt': ticket.issuedAt.add(Duration(hours: 2)).toIso8601String(),
    });
  }

  Map<String, dynamic> _votingToJson(Voting voting) {
    return {
      'id': voting.id,
      'title': _sanitizeOutput(voting.title),
      'type': voting.type.name,
      'status': voting.status.name,
      'canVote': voting.canVote,
      'endsAt': voting.endsAt?.toIso8601String(),
    };
  }

  // ===== INPUT SANITIZATION =====

  /// Validate device fingerprint format (SHA-256 hex string)
  bool _isValidFingerprint(String fingerprint) {
    return fingerprint.length == 64 &&
        RegExp(r'^[a-f0-9]+$').hasMatch(fingerprint);
  }

  /// Sanitize input to prevent injection attacks
  String _sanitizeInput(String input) {
    // Remove any potentially dangerous characters
    return input
        .replaceAll(RegExp(r'[<>"\x27;]'), '') // Remove HTML/SQL special chars
        .trim();
  }

  /// Sanitize output to prevent XSS
  String _sanitizeOutput(String output) {
    return output
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  // ===== AUDIT LOGGING =====

  Future<void> _logMeetingJoin({
    required String meetingId,
    required String meetingPassId,
    required String deviceFingerprint,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      action: AuditAction.meetingJoined,
      sessionId: '', // No session yet
      timestamp: DateTime.now().toUtc(),
      userHash: deviceFingerprint,
      details: 'meetingPassId:$meetingPassId',
      previousHash: '',
      hash: '',
      meetingId: meetingId,
    );

    final lastLog = await auditLogs.getLastLog();
    auditLog.previousHash = lastLog?.hash ?? '0';
    auditLog.hash = auditLog.computeHash();

    await auditLogs.insert(auditLog);
  }

  Future<void> _logTicketIssued({
    required String meetingId,
    required String sessionId,
    required String ticketId,
    required String deviceFingerprint,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      action: AuditAction.ticketIssued,
      sessionId: sessionId,
      timestamp: DateTime.now().toUtc(),
      userHash: deviceFingerprint,
      details: 'ticketId:$ticketId',
      previousHash: '',
      hash: '',
      meetingId: meetingId,
    );

    final lastLog = await auditLogs.getLastLog();
    auditLog.previousHash = lastLog?.hash ?? '0';
    auditLog.hash = auditLog.computeHash();

    await auditLogs.insert(auditLog);
  }

  Future<void> _logSecurityViolation({
    required String meetingId,
    required String sessionId,
    required String reason,
    required String deviceFingerprint,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      action: AuditAction.securityViolation,
      sessionId: sessionId,
      timestamp: DateTime.now().toUtc(),
      userHash: deviceFingerprint,
      details: 'SECURITY_VIOLATION:$reason',
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
