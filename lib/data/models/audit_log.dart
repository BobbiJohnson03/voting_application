import "package:vote_app_thesis/models/enums.dart";
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

part 'audit_log.g.dart';

@HiveType(typeId: 14)
class AuditLog extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final AuditAction action;
  @HiveField(2)
  final String sessionId;
  @HiveField(3)
  final DateTime timestamp;
  @HiveField(4)
  final String userHash;
  @HiveField(5)
  String previousHash; // Mutable for hash chain computation
  @HiveField(6)
  String hash; // Mutable for hash chain computation
  @HiveField(7)
  final String details; // Changed to String for simpler serialization
  @HiveField(8)
  String meetingId;

  AuditLog({
    required this.id,
    required this.action,
    required this.sessionId,
    required this.timestamp,
    required this.userHash,
    required this.previousHash,
    required this.hash,
    required this.details,
    required this.meetingId,
  });

  bool get isChainValid {
    final computed = computeHash();
    return computed == hash;
  }

  String computeHash() {
    final data =
        '$id${action.name}$sessionId${timestamp.millisecondsSinceEpoch}$userHash$previousHash$meetingId$details';
    return sha256.convert(utf8.encode(data)).toString();
  }
}
