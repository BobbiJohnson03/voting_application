import 'package:shelf/shelf.dart';
import 'dart:convert';

/// Simple in-memory rate limiter for security
/// Prevents brute-force attacks on sensitive endpoints
class RateLimiter {
  // Track requests per IP address
  final Map<String, List<DateTime>> _requestLog = {};

  // Configuration
  final int maxRequests;
  final Duration window;
  final Duration blockDuration;

  // Blocked IPs
  final Map<String, DateTime> _blockedIps = {};

  // Sensitive endpoints that need stricter limiting
  static const _sensitiveEndpoints = ['/join', '/ticket', '/vote'];

  RateLimiter({
    this.maxRequests = 30, // Max 30 requests per window
    this.window = const Duration(minutes: 1),
    this.blockDuration = const Duration(minutes: 5),
  });

  /// Shelf middleware for rate limiting
  Middleware get middleware {
    return (Handler innerHandler) {
      return (Request request) async {
        final clientIp = _getClientIp(request);
        final path = request.requestedUri.path;

        // Check if IP is blocked
        if (_isBlocked(clientIp)) {
          final unblockTime = _blockedIps[clientIp]!;
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

        // Apply stricter limits for sensitive endpoints
        final isSensitive = _sensitiveEndpoints.any((e) => path.startsWith(e));
        final effectiveMax = isSensitive ? (maxRequests ~/ 2) : maxRequests;

        // Check rate limit
        if (!_checkRateLimit(clientIp, effectiveMax)) {
          // Block the IP
          _blockedIps[clientIp] = DateTime.now().add(blockDuration);

          return Response(
            429,
            body: jsonEncode({
              'error':
                  'Rate limit exceeded. You have been temporarily blocked.',
              'retryAfter': blockDuration.inSeconds,
            }),
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': blockDuration.inSeconds.toString(),
            },
          );
        }

        // Record the request
        _recordRequest(clientIp);

        // Continue to handler
        return innerHandler(request);
      };
    };
  }

  /// Extract client IP from request
  String _getClientIp(Request request) {
    // Check X-Forwarded-For header (for proxied requests)
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) {
      return forwarded.split(',').first.trim();
    }

    // Check X-Real-IP header
    final realIp = request.headers['x-real-ip'];
    if (realIp != null && realIp.isNotEmpty) {
      return realIp;
    }

    // Fallback: use a default identifier
    // In Shelf, we don't have direct access to socket IP in the request
    // This is a limitation - in production, use a reverse proxy that sets headers
    return 'unknown-client';
  }

  /// Check if IP is currently blocked
  bool _isBlocked(String ip) {
    final unblockTime = _blockedIps[ip];
    if (unblockTime == null) return false;

    if (DateTime.now().isAfter(unblockTime)) {
      // Block expired, remove it
      _blockedIps.remove(ip);
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
  void _recordRequest(String ip) {
    _requestLog.putIfAbsent(ip, () => []);
    _requestLog[ip]!.add(DateTime.now());

    // Cleanup old entries periodically
    if (_requestLog[ip]!.length > maxRequests * 2) {
      final cutoff = DateTime.now().subtract(window);
      _requestLog[ip]!.removeWhere((time) => time.isBefore(cutoff));
    }
  }

  /// Clear all rate limit data (for testing)
  void clear() {
    _requestLog.clear();
    _blockedIps.clear();
  }

  /// Get current blocked IPs (for monitoring)
  Map<String, DateTime> get blockedIps => Map.unmodifiable(_blockedIps);
}
