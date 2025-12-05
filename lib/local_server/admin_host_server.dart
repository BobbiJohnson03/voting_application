import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'broadcast_manager.dart';
import 'auto_close_manager.dart';
import 'logic_join_ticket.dart';
import 'logic_vote.dart';
import 'logic_manifest.dart';
import 'logic_admin.dart';
import 'static_assets_handler.dart';
import 'rate_limiter.dart';

import '../data/repositories/meeting_repository.dart';
import '../data/repositories/voting_repository.dart';
import '../data/repositories/ticket_repository.dart';
import '../data/repositories/vote_repository.dart';
import '../data/repositories/question_repository.dart';
import '../data/repositories/meeting_pass_repository.dart';
import '../data/repositories/signing_key_repository.dart';
import '../data/repositories/audit_log_repository.dart';
import 'package:flutter/foundation.dart';

class AdminHostServer {
  HttpServer? _server;

  late final BroadcastManager broadcast;
  late final AutoCloseManager autoClose;
  late final RateLimiter rateLimiter;

  late final LogicJoinTicket lt;
  late final LogicVote lv;
  late final LogicManifest lm;
  late final LogicAdmin la;

  // Store repositories for verification and stats endpoints
  late final MeetingRepository _meetings;
  late final VotingRepository _votings;
  late final TicketRepository _tickets;
  late final MeetingPassRepository _meetingPasses;
  late final VoteRepository _votes;
  late final SigningKeyRepository _signingKeys;
  late final AuditLogRepository _auditLogs;

  AdminHostServer({
    required MeetingRepository meetings,
    required VotingRepository votings,
    required TicketRepository tickets,
    required VoteRepository votes,
    required QuestionRepository questions,
    required MeetingPassRepository meetingPasses,
    required SigningKeyRepository signingKeys,
    required AuditLogRepository auditLogs,
  }) {
    broadcast = BroadcastManager();
    rateLimiter = RateLimiter();

    // Store for verification and stats endpoints
    _meetings = meetings;
    _votings = votings;
    _tickets = tickets;
    _meetingPasses = meetingPasses;
    _votes = votes;
    _signingKeys = signingKeys;
    _auditLogs = auditLogs;

    lt = LogicJoinTicket(
      meetings: meetings,
      votings: votings,
      tickets: tickets,
      meetingPasses: meetingPasses,
      auditLogs: auditLogs,
      broadcast: broadcast,
    );

    lv = LogicVote(
      votings: votings,
      tickets: tickets,
      votes: votes,
      questions: questions,
      signingKeys: signingKeys,
      auditLogs: auditLogs,
      broadcast: broadcast,
    );

    lm = LogicManifest(votings: votings, questions: questions);

    la = LogicAdmin(
      meetings: meetings,
      votings: votings,
      votes: votes,
      questions: questions,
      auditLogs: auditLogs,
      broadcast: broadcast,
    );

    autoClose = AutoCloseManager(meetings, votings, broadcast);
  }

  Future<void> start({InternetAddress? address, int port = 8080}) async {
    final router = Router()
      ..get('/health', (req) => _jsonResponse({'ok': true}))
      ..get('/manifest', lm.manifest)
      ..get('/sessions', lm.sessions)
      ..post('/join', lt.joinMeeting)
      ..post('/ticket', lt.requestTicket)
      ..post('/vote', lv.submitVote)
      ..get('/admin/results', la.results)
      ..post('/admin/close', la.closeSession)
      ..get('/admin/verify-chain', _verifyHashChain)
      ..get('/admin/audit-logs', _getAuditLogs)
      ..get('/admin/stats', _getStats)
      ..get('/ws', broadcast.handleWs)
      ..options('/<ignored|.*>', (req) => Response.ok(''));

    final apiHandler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware)
        .addMiddleware(rateLimiter.middleware)
        .addHandler(router.call);

    // Build the final handler with static file serving
    // IMPORTANT: API must be checked FIRST, then static files
    // On Android/iOS: serve from bundled assets (assets/web/)
    // On Desktop/Dev: serve from build/web directory
    Handler handler;
    try {
      if (isMobilePlatform) {
        // Mobile: serve web files from Flutter assets bundle
        // These files must be copied from build/web to assets/web before building APK
        final staticHandler = createAssetStaticHandler();
        // API first, then static files (API returns 404 for unknown routes)
        handler = Cascade().add(apiHandler).add(staticHandler).handler;
        if (kDebugMode) {
          debugPrint(
            '📱 Using asset-based static handler for mobile PWA hosting',
          );
        }
      } else {
        // Desktop/Dev: serve from filesystem if build/web exists
        final webDir = Directory('build/web');
        if (await webDir.exists()) {
          final staticHandler = createStaticHandler(
            'build/web',
            defaultDocument: 'index.html',
            listDirectories: false,
          );
          // API first, then static files
          handler = Cascade().add(apiHandler).add(staticHandler).handler;
          if (kDebugMode) {
            debugPrint('🖥️ Using filesystem static handler from build/web');
          }
        } else {
          // No web directory - API only
          handler = apiHandler;
          if (kDebugMode) {
            debugPrint('⚠️ No build/web found - API only, no PWA hosting');
          }
        }
      }
    } catch (e) {
      // If static handler creation fails, just use API handler
      if (kDebugMode) {
        debugPrint('Static file handler not available, using API only: $e');
      }
      handler = apiHandler;
    }

    _server = await io.serve(handler, address ?? InternetAddress.anyIPv4, port);
    autoClose.start();

    if (kDebugMode) {
      debugPrint(
        'AdminHost listening on http://${_server!.address.address}:$port',
      );
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    autoClose.stop();
    _server = null;
  }

  static Middleware get _corsMiddleware {
    Response addCors(Response res) => res.change(
      headers: {
        ...res.headers,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Origin, Content-Type',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      },
    );

    return (inner) => (req) async {
      if (req.method == 'OPTIONS') {
        return addCors(Response.ok(''));
      }
      final res = await inner(req);
      return addCors(res);
    };
  }

  Response _jsonResponse(Map<String, dynamic> data, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Verify hash chain integrity for a session
  Future<Response> _verifyHashChain(Request req) async {
    final sessionId = req.requestedUri.queryParameters['sessionId'];
    if (sessionId == null) {
      return _jsonResponse({'error': 'Missing sessionId'}, status: 400);
    }

    final votes = await _votes.forSession(sessionId);
    if (votes.isEmpty) {
      return _jsonResponse({
        'valid': true,
        'message': 'No votes in session',
        'voteCount': 0,
      });
    }

    // Sort by submission time
    votes.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));

    // Get signing key for signature validation
    final sessionKeys = await _signingKeys.forSession(sessionId);
    final signingKey = sessionKeys.isNotEmpty ? sessionKeys.first : null;

    // Verify chain
    final errors = <String>[];

    // Check first vote
    if (votes.first.previousVoteHash != '0') {
      errors.add('First vote has invalid previousHash (expected "0")');
    }

    // Check all votes
    for (var i = 0; i < votes.length; i++) {
      final vote = votes[i];

      // Verify hash integrity
      if (!vote.isIntegrityValid) {
        errors.add('Vote ${i + 1} (${vote.id}): Hash integrity failed');
      }

      // Verify signature if key available
      if (signingKey != null && !vote.validateSignature(signingKey.secret)) {
        errors.add('Vote ${i + 1} (${vote.id}): Invalid signature');
      }

      // Verify chain link (except first)
      if (i > 0 && vote.previousVoteHash != votes[i - 1].voteHash) {
        errors.add('Vote ${i + 1} (${vote.id}): Chain link broken');
      }
    }

    return _jsonResponse({
      'valid': errors.isEmpty,
      'voteCount': votes.length,
      'errors': errors,
      'lastHash': votes.last.voteHash,
    });
  }

  /// Get audit logs for a session or meeting
  Future<Response> _getAuditLogs(Request req) async {
    final sessionId = req.requestedUri.queryParameters['sessionId'];
    final meetingId = req.requestedUri.queryParameters['meetingId'];

    List logs;
    if (sessionId != null) {
      logs = await _auditLogs.forSession(sessionId);
    } else if (meetingId != null) {
      logs = await _auditLogs.forMeeting(meetingId);
    } else {
      return _jsonResponse({
        'error': 'Missing sessionId or meetingId',
      }, status: 400);
    }

    // Sort by timestamp
    logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Verify audit log chain integrity
    final chainErrors = <String>[];
    for (var i = 0; i < logs.length; i++) {
      if (!logs[i].isChainValid) {
        chainErrors.add('Log ${i + 1} (${logs[i].id}): Hash integrity failed');
      }
      if (i > 0 && logs[i].previousHash != logs[i - 1].hash) {
        chainErrors.add('Log ${i + 1} (${logs[i].id}): Chain link broken');
      }
    }

    return _jsonResponse({
      'logs': logs
          .map(
            (log) => {
              'id': log.id,
              'action': log.action.name,
              'sessionId': log.sessionId,
              'meetingId': log.meetingId,
              'timestamp': log.timestamp.toIso8601String(),
              'details': log.details,
              'valid': log.isChainValid,
            },
          )
          .toList(),
      'chainValid': chainErrors.isEmpty,
      'chainErrors': chainErrors,
      'count': logs.length,
    });
  }

  /// Get real-time statistics for a meeting
  Future<Response> _getStats(Request req) async {
    final meetingId = req.requestedUri.queryParameters['meetingId'];

    if (meetingId == null) {
      return _jsonResponse({'error': 'Missing meetingId'}, status: 400);
    }

    try {
      // Get meeting info
      final meeting = await _meetings.get(meetingId);
      if (meeting == null) {
        return _jsonResponse({'error': 'Meeting not found'}, status: 404);
      }

      // Get all passes (joined devices) for this meeting
      final passes = await _meetingPasses.forMeeting(meetingId);
      final joinedDevices = passes.where((p) => !p.revoked).length;

      // Get all votings for this meeting
      final votings = await _votings.forMeeting(meetingId);

      // Build voting stats
      final votingStats = <Map<String, dynamic>>[];
      int totalVotes = 0;

      for (final voting in votings) {
        final tickets = await _tickets.forSession(voting.id);
        final votes = await _votes.forSession(voting.id);
        
        // Count unique voters (used tickets)
        final usedTickets = tickets.where((t) => t.isUsed).length;
        final voteCount = votes.length;
        totalVotes += voteCount;

        votingStats.add({
          'id': voting.id,
          'title': voting.title,
          'status': voting.status.name,
          'type': voting.type.name,
          'ticketsIssued': tickets.length,
          'votesSubmitted': voteCount,
          'uniqueVoters': usedTickets,
          'endsAt': voting.endsAt?.toIso8601String(),
          'canVote': voting.canVote,
        });
      }

      return _jsonResponse({
        'meetingId': meetingId,
        'meetingTitle': meeting.title,
        'joinCode': meeting.joinCode,
        'isActive': meeting.isActive,
        'joinedDevices': joinedDevices,
        'totalVotings': votings.length,
        'totalVotes': totalVotes,
        'votings': votingStats,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return _jsonResponse({
        'error': 'Failed to get stats: $e',
      }, status: 500);
    }
  }
}
