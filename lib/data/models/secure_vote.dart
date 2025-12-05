import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

part 'secure_vote.g.dart';

@HiveType(typeId: 11)
class SecureVote extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String sessionId;
  @HiveField(2)
  final String questionId;
  @HiveField(3)
  final List<String> selectedOptionIds;
  @HiveField(4)
  final DateTime submittedAt;
  @HiveField(5)
  final String ticketId;
  @HiveField(6)
  final String previousVoteHash;
  @HiveField(7)
  final String voteHash;
  @HiveField(8)
  final String nonce;
  @HiveField(9)
  final String signature;

  SecureVote({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.selectedOptionIds,
    required this.submittedAt,
    required this.ticketId,
    required this.previousVoteHash,
    required this.voteHash,
    required this.nonce,
    required this.signature,
  });

  // Cache for performance optimization
  String? _cachedHash;

  String computeHash() {
    _cachedHash ??= _computeHashInternal();
    return _cachedHash!;
  }

  String _computeHashInternal() {
    final joinedOptionIds = selectedOptionIds.join('|');
    final submittedAtMs = submittedAt.millisecondsSinceEpoch;
    final data =
        '$sessionId$questionId$joinedOptionIds$ticketId$nonce$submittedAtMs$previousVoteHash';
    return sha256.convert(utf8.encode(data)).toString();
  }

  // Enhanced validation
  bool get isIntegrityValid {
    return computeHash() == voteHash;
  }

  bool validateSignature(String secretKey) {
    final expectedSignature = generateHMAC(secretKey, computeHash());
    return expectedSignature == signature;
  }

  static String generateHMAC(String secret, String data) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }
}
