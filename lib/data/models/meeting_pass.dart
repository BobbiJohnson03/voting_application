import 'package:hive/hive.dart';
part 'meeting_pass.g.dart';

/* permission to join the whole meeting */

@HiveType(typeId: 13)
class MeetingPass extends HiveObject {
  @HiveField(0)
  String passId; // UUID

  @HiveField(1)
  String meetingId;

  @HiveField(2)
  DateTime issuedAt;

  @HiveField(3)
  bool revoked; /* If admin decides to invalidate a ticket (e.g., participant leaves the meeting, or technical issue),
they can mark revoked = true to disable it. */

  @HiveField(4)
  String? deviceFingerprintHash; // może mieć wartość null

  /* NOWE: powód unieważnienia (np. 'left_meeting', 'manual', 'admin') */
  @HiveField(5)
  String? revokedReason;

  MeetingPass({
    required this.passId,
    required this.meetingId,
    DateTime? issuedAt, // Make optional with default
    this.revoked = false,
    this.deviceFingerprintHash,
    this.revokedReason,
  }) : issuedAt = issuedAt ?? DateTime.now(); // Auto-set timestamp
}
