import 'package:hive/hive.dart';
part 'ticket.g.dart';

@HiveType(typeId: 10)
class Ticket extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String sessionId;
  @HiveField(2)
  final DateTime issuedAt;
  @HiveField(3)
  bool isUsed;
  @HiveField(4)
  final String meetingPassId;
  @HiveField(5)
  final String deviceFingerprint; // Lock to device

  Ticket({
    required this.id,
    required this.sessionId,
    required this.issuedAt,
    required this.isUsed,
    required this.meetingPassId,
    required this.deviceFingerprint,
  });

  bool get isValid =>
      !isUsed && DateTime.now().isBefore(issuedAt.add(Duration(hours: 2)));

  bool get isExpired =>
      DateTime.now().isAfter(issuedAt.add(Duration(hours: 2)));

  // Enhanced device validation
  bool get isDeviceValid => deviceFingerprint.isNotEmpty;
}
