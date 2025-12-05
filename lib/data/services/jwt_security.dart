import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../repositories/signing_key_repository.dart';

class JWTSecurity {
  final SigningKeyRepository _signingKeyRepo;

  JWTSecurity(this._signingKeyRepo);

  Future<String> createSessionToken({
    required String sessionId,
    required String keyId,
  }) async {
    // Get the secret from repository instead of static map
    final signingKey = await _signingKeyRepo.get(keyId);
    if (signingKey == null) {
      throw Exception('Signing key not found for keyId: $keyId');
    }

    final jwt = JWT({
      'sessionId': sessionId,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000, // JWT uses seconds
      'exp':
          DateTime.now().add(Duration(hours: 2)).millisecondsSinceEpoch ~/
          1000, // 2 hour expiry
    }, issuer: 'voting_application');

    return jwt.sign(SecretKey(signingKey.secret));
  }

  Future<bool> verifyVoteToken(String token, String keyId) async {
    final signingKey = await _signingKeyRepo.get(keyId);
    if (signingKey == null) return false;

    try {
      final jwt = JWT.verify(token, SecretKey(signingKey.secret));
      return jwt.payload['sessionId'] != null;
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final jwt = JWT.decode(token);
      return jwt.payload;
    } catch (e) {
      return null;
    }
  }

  // New: Extract session ID from token
  static String? getSessionIdFromToken(String token) {
    final payload = decodeToken(token);
    return payload?['sessionId']?.toString();
  }
}
