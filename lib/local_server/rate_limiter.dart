import 'package:shelf/shelf.dart';
import 'dart:convert';

/// Rate limiter optimized for local voting with up to 35 participants
/// Uses fingerprint-based tracking since we can't get real IPs in Shelf
class RateLimiter {
  // Track requests per client identifier
  final Map<String, List<DateTime>> _requestLog = {};

  // Configuration - optimized for 35 participants voting simultaneously
  final int maxRequestsPerClient;
  final int maxGlobalRequestsPerSecond;
  final Duration window;
  final Duration blockDuration;

  // Blocked clients
  final Map<String, DateTime> _blockedClients = {};

  // Global request counter (for DDoS protection)
  final List<DateTime> _globalRequests = [];

  // Max participants
  static const int maxParticipants = 35;

  RateLimiter({
    this.maxRequestsPerClient = 60, // Per client: 60 requests per minute (enough for voting flow)
    this.maxGlobalRequestsPerSecond = 100, // Global: 100 req/s (35 users * ~3 req each)
    this.window = const Duration(minutes: 1),
    this.blockDuration = const Duration(minutes: 2), // Shorter block time
  });

  /// Shelf middleware for rate limiting
  Middleware get middleware {
    return (Handler innerHandler) {
      return (Request request) async {
        final clientId = _getClientIdentifier(request);
        final path = request.requestedUri.path;

        // Skip rate limiting for static files (PWA assets)
        if (_isStaticFile(path)) {
          return innerHandler(request);
        }

        // Check global rate limit first (DDoS protection)
        if (!_checkGlobalLimit()) {
          return Response(
            503,
            body: jsonEncode({
              'error': 'Server busy. Please try again.',
              'retryAfter': 1,
            }),
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': '1',
            },
          );
        }

        // Check if client is blocked
        if (_isBlocked(clientId)) {
          final unblockTime = _blockedClients[clientId]!;
          final remaining = unblockTime.difference(DateTime.now()).inSeconds;
          return Response(
            429,
            body: jsonEncode({
              'error': 'Too many requests. Try again in $remaining seconds.',
              'retryAfter': remaining,
            }),
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': remaining.toString(),
            },
          );
        }

        // Check per-client rate limit
        if (!_checkRateLimit(clientId, maxRequestsPerClient)) {
          // Block the client temporarily
          _blockedClients[clientId] = DateTime.now().add(blockDuration);

          return Response(
            429,
            body: jsonEncode({
              'error': 'Rate limit exceeded. Please slow down.',
              'retryAfter': blockDuration.inSeconds,
            }),
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': blockDuration.inSeconds.toString(),
            },
          );
        }

        // Record the request
        _recordRequest(clientId);
        _recordGlobalRequest();

        // Continue to handler
        return innerHandler(request);
      };
    };
  }

  /// Check if path is a static file (don't rate limit these)
  bool _isStaticFile(String path) {
    return path.endsWith('.html') ||
        path.endsWith('.js') ||
        path.endsWith('.css') ||
        path.endsWith('.png') ||
        path.endsWith('.ico') ||
        path.endsWith('.json') ||
        path.endsWith('.wasm') ||
        path.endsWith('.ttf') ||
        path.endsWith('.woff') ||
        path.endsWith('.woff2') ||
        path == '/' ||
        path.isEmpty;
  }

  /// Check global request rate (DDoS protection)
  bool _checkGlobalLimit() {
    final now = DateTime.now();
    final oneSecondAgo = now.subtract(const Duration(seconds: 1));
    
    // Remove old entries
    _globalRequests.removeWhere((time) => time.isBefore(oneSecondAgo));
    
    return _globalRequests.length < maxGlobalRequestsPerSecond;
  }

  /// Record global request
  void _recordGlobalRequest() {
    _globalRequests.add(DateTime.now());
  }

  /// Extract client identifier from request
  /// Uses fingerprint from request body/header, or User-Agent as fallback
  String _getClientIdentifier(Request request) {
    // Try to get fingerprint from header (set by client)
    final fingerprint = request.headers['x-device-fingerprint'];
    if (fingerprint != null && fingerprint.isNotEmpty) {
      return 'fp:$fingerprint';
    }

    // Use User-Agent as identifier (different browsers/devices have different UA)
    final userAgent = request.headers['user-agent'] ?? '';
    if (userAgent.isNotEmpty) {
      // Create a simple hash of user agent to identify client
      return 'ua:${userAgent.hashCode}';
    }

    // Fallback to remote address if available via headers
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) {
      return 'ip:${forwarded.split(',').first.trim()}';
    }

    // Last resort - treat as unknown
    return 'unknown:${DateTime.now().millisecondsSinceEpoch ~/ 60000}'; // Changes every minute
  }

  /// Check if client is currently blocked
  bool _isBlocked(String clientId) {
    final unblockTime = _blockedClients[clientId];
    if (unblockTime == null) return false;

    if (DateTime.now().isAfter(unblockTime)) {
      // Block expired, remove it
      _blockedClients.remove(clientId);
      return false;
    }

    return true;
  }

  /// Check if request is within rate limit
  bool _checkRateLimit(String ip, int limit) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);

    // Get request history for this IP
    final history = _requestLog[ip] ?? [];

    // Remove old entries
    history.removeWhere((time) => time.isBefore(cutoff));

    // Check limit
    return history.length < limit;
  }

  /// Record a request
  void _recordRequest(String clientId) {
    _requestLog.putIfAbsent(clientId, () => []);
    _requestLog[clientId]!.add(DateTime.now());

    // Cleanup old entries periodically
    if (_requestLog[clientId]!.length > maxRequestsPerClient * 2) {
      final cutoff = DateTime.now().subtract(window);
      _requestLog[clientId]!.removeWhere((time) => time.isBefore(cutoff));
    }
  }

  /// Clear all rate limit data (for testing)
  void clear() {
    _requestLog.clear();
    _blockedClients.clear();
    _globalRequests.clear();
  }

  /// Get current blocked clients (for monitoring)
  Map<String, DateTime> get blockedClients => Map.unmodifiable(_blockedClients);
}
