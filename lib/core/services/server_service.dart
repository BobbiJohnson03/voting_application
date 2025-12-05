import 'dart:io';
import 'package:flutter/foundation.dart';
import '../local_server/admin_host_server.dart';
import '../repositories/meeting_repository.dart';
import '../repositories/voting_repository.dart';
import '../repositories/ticket_repository.dart';
import '../repositories/vote_repository.dart';
import '../repositories/question_repository.dart';
import '../repositories/meeting_pass_repository.dart';
import '../repositories/signing_key_repository.dart';
import '../repositories/audit_log_repository.dart';

/// Manages the local voting server lifecycle
/// Server auto-starts when service is initialized (admin mode)
class ServerService {
  AdminHostServer? _server;
  String? _serverIp;
  int _port = 8080;
  bool _isRunning = false;

  // Repositories
  late final MeetingRepository _meetings;
  late final VotingRepository _votings;
  late final TicketRepository _tickets;
  late final VoteRepository _votes;
  late final QuestionRepository _questions;
  late final MeetingPassRepository _meetingPasses;
  late final SigningKeyRepository _signingKeys;
  late final AuditLogRepository _auditLogs;

  ServerService() {
    // Initialize repositories
    _meetings = MeetingRepository();
    _votings = VotingRepository();
    _tickets = TicketRepository();
    _votes = VoteRepository();
    _questions = QuestionRepository();
    _meetingPasses = MeetingPassRepository();
    _signingKeys = SigningKeyRepository();
    _auditLogs = AuditLogRepository();
  }

  /// Auto-start server when admin page opens
  /// Returns the server URL (e.g., "http://192.168.1.100:8080")
  Future<String> startServer() async {
    // Hosting the Shelf server is not possible on Flutter Web (no dart:io sockets).
    // Guard early to provide a clear message in admin mode if launched in a browser.
    if (kIsWeb) {
      throw Exception(
        'Admin server is not available on Web. Run Admin mode on an Android device (APK) or a desktop build.',
      );
    }

    // If server is already running, return the current URL
    if (_isRunning && _server != null) {
      return _getServerUrl();
    }

    // Make sure to stop any existing server instance first
    await stopServer();

    try {
      // Use current network connection (admin connects to WiFi via system settings)
      _serverIp = await _getLocalIpAddress();

      if (_serverIp == null) {
        throw Exception(
          'Could not determine local IP address. Please ensure you are connected to a network.',
        );
      }

      // Create and start server
      _server = AdminHostServer(
        meetings: _meetings,
        votings: _votings,
        tickets: _tickets,
        votes: _votes,
        questions: _questions,
        meetingPasses: _meetingPasses,
        signingKeys: _signingKeys,
        auditLogs: _auditLogs,
      );

      // Start server on all interfaces (0.0.0.0) so other devices can connect
      await _server!.start(address: InternetAddress.anyIPv4, port: _port);

      _isRunning = true;

      if (kDebugMode) {
        debugPrint('✅ Server started on $_serverIp:$_port');
      }

      return _getServerUrl();
    } catch (e) {
      _isRunning = false;
      if (kDebugMode) {
        debugPrint('❌ Failed to start server: $e');
      }
      rethrow;
    }
  }

  /// Stop the server if it's running
  Future<void> stopServer() async {
    if (_server != null) {
      try {
        await _server!.stop();
        if (kDebugMode) {
          debugPrint('🛑 Server stopped');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error stopping server: $e');
        }
      } finally {
        _server = null;
        _isRunning = false;
      }
    }
  }

  /// Get server URL for clients to connect
  String getServerUrl() {
    if (!_isRunning || _serverIp == null) {
      throw StateError('Server is not running');
    }
    return _getServerUrl();
  }

  String _getServerUrl() {
    return 'http://$_serverIp:$_port';
  }

  /// Check if server is running
  bool get isRunning => _isRunning;

  /// Get server IP address
  String? get serverIp => _serverIp;

  /// Get server port
  int get port => _port;

  /// Get repositories (for direct access if needed)
  MeetingRepository get meetings => _meetings;
  VotingRepository get votings => _votings;
  TicketRepository get tickets => _tickets;
  VoteRepository get votes => _votes;
  QuestionRepository get questions => _questions;
  MeetingPassRepository get meetingPasses => _meetingPasses;
  SigningKeyRepository get signingKeys => _signingKeys;
  AuditLogRepository get auditLogs => _auditLogs;

  /// Get device's local IP address (e.g., 192.168.1.100)
  /// Returns the first non-loopback IPv4 address
  Future<String?> _getLocalIpAddress() async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Prefer common private LAN ranges:
      // 1) 192.168.0.0/16, 2) 10.0.0.0/8, 3) 172.16.0.0/12
      String? candidate;

      bool _isPrivate172(String ip) {
        final parts = ip.split('.');
        if (parts.length != 4) return false;
        final first = int.tryParse(parts[0]) ?? -1;
        final second = int.tryParse(parts[1]) ?? -1;
        return first == 172 && second >= 16 && second <= 31;
      }

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type != InternetAddressType.IPv4 || addr.isLoopback)
            continue;
          final ip = addr.address;
          if (ip.startsWith('192.168.')) return ip;
          candidate ??= ip.startsWith('10.') ? ip : candidate;
          if (candidate == null && _isPrivate172(ip)) candidate = ip;
        }
      }

      if (candidate != null) return candidate;

      // Fallback: return first IPv4 address if no 192.168.x.x found
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting local IP: $e');
      }
      return null;
    }
  }
}
