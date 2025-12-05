import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiNetwork {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  ApiNetwork(
    String baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : baseUrl = _normalizeBase(baseUrl),
       _client = client ?? http.Client();

  void close() => _client.close();

  // ============ GENERIC GET ============
  /// Generic GET helper that returns decoded JSON.
  /// Used e.g. in SessionsSelectionPage to fetch `/manifest`.
  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _client.get(uri).timeout(timeout);
    return _decodeJsonOrThrow(res, expectOk: true);
  }

  // ============ HEALTH CHECK ============
  Future<Map<String, dynamic>> health() async {
    final uri = Uri.parse('$baseUrl/health');
    final res = await _client.get(uri).timeout(timeout);
    return _decodeJsonOrThrow(res, expectOk: true);
  }

  // ============ USER FLOW METHODS ============

  /// Join a meeting and get a MeetingPass
  Future<Map<String, dynamic>> joinMeeting({
    required String meetingId,
    required String deviceFingerprint,
  }) {
    return _postJson('/join', {
      'meetingId': meetingId,
      'deviceFingerprint': deviceFingerprint,
    });
  }

  /// Join a meeting by join code (for web/PWA clients)
  Future<Map<String, dynamic>> joinMeetingByCode({
    required String joinCode,
    required String deviceFingerprint,
  }) {
    return _postJson('/join', {
      'joinCode': joinCode,
      'deviceFingerprint': deviceFingerprint,
    });
  }

  /// Request a voting ticket for a specific session
  Future<Map<String, dynamic>> requestTicket({
    required String meetingPassId,
    required String sessionId,
    required String deviceFingerprint,
  }) {
    return _postJson('/ticket', {
      'meetingPassId': meetingPassId,
      'sessionId': sessionId,
      'deviceFingerprint': deviceFingerprint,
    });
  }

  /// Submit a secure vote
  /// deviceFingerprint is required for security validation
  Future<Map<String, dynamic>> submitVote({
    required String ticketId,
    required String sessionId,
    required String questionId,
    required List<String> selectedOptions,
    required String deviceFingerprint,
  }) {
    return _postJson('/vote', {
      'ticketId': ticketId,
      'sessionId': sessionId,
      'questionId': questionId,
      'selectedOptionIds': selectedOptions,
      'deviceFingerprint': deviceFingerprint,
    });
  }

  // ============ SESSION DATA METHODS ============

  /// Get voting manifest (questions & options) for a session
  Future<Map<String, dynamic>> getManifest(String sessionId) async {
    final uri = Uri.parse('$baseUrl/manifest?sessionId=$sessionId');
    final res = await _client.get(uri).timeout(timeout);
    return _decodeJsonOrThrow(res, expectOk: true);
  }

  /// Get voting results for a session
  Future<Map<String, dynamic>> getResults(String sessionId) async {
    final uri = Uri.parse('$baseUrl/admin/results?sessionId=$sessionId');
    final res = await _client.get(uri).timeout(timeout);
    return _decodeJsonOrThrow(res, expectOk: true);
  }

  // ============ ADMIN METHODS ============

  Future<Map<String, dynamic>> adminClose(String sessionId) {
    return _postJson('/admin/close', {'sessionId': sessionId});
  }

  Future<Map<String, dynamic>> adminArchive(String sessionId) {
    return _postJson('/admin/archive', {'sessionId': sessionId});
  }

  Future<Map<String, dynamic>> adminSeedSession(Map<String, dynamic> payload) {
    return _postJson('/admin/session/seed', payload);
  }

  Future<http.Response> adminExportPdfRaw(String sessionId) async {
    final uri = Uri.parse('$baseUrl/admin/export/pdf?sessionId=$sessionId');
    final res = await _client.get(uri).timeout(timeout);
    if (res.statusCode >= 400) {
      throw ApiException(
        statusCode: res.statusCode,
        message: 'Export failed',
        rawBody: res.body,
      );
    }
    return res;
  }

  // ============ WEB SOCKET ============

  Uri wsUri(String meetingId) {
    final isHttps = baseUrl.startsWith('https://');
    final scheme = isHttps ? 'wss' : 'ws';
    final u = Uri.parse(baseUrl);
    return Uri(
      scheme: scheme,
      host: u.host,
      port: u.port,
      path: '/ws',
      // Fixed: server expects 'mid' not 'meetingId'
      queryParameters: {'mid': meetingId},
    );
  }

  // ============ PRIVATE METHODS ============

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decodeJsonOrThrow(res, expectOk: true);
  }

  static Map<String, dynamic> _decodeJsonOrThrow(
    http.Response res, {
    required bool expectOk,
  }) {
    Map<String, dynamic> json;
    try {
      json = res.body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        statusCode: res.statusCode,
        message: 'Invalid JSON from server',
        rawBody: res.body,
      );
    }

    if (res.statusCode >= 400) {
      throw ApiException(
        statusCode: res.statusCode,
        message: json['error']?.toString() ?? 'HTTP ${res.statusCode}',
        rawBody: res.body,
      );
    }

    if (expectOk && json.containsKey('error')) {
      throw ApiException(
        statusCode: res.statusCode,
        message: json['error']?.toString() ?? 'Server error',
        rawBody: res.body,
      );
    }

    return json;
  }

  static String _normalizeBase(String base) {
    var b = base.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? rawBody;

  ApiException({required this.statusCode, required this.message, this.rawBody});

  // ✅ User-friendly error messages
  String get userMessage {
    switch (statusCode) {
      case 400:
        return 'Invalid request - please check your input';
      case 403:
        return 'Access denied - check your permissions';
      case 404:
        return 'Meeting or session not found';
      case 409:
        return 'Vote already submitted or ticket already used';
      case 500:
        return 'Server error - please try again later';
      default:
        return message;
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
