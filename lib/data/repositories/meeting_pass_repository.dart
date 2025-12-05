import '../_boxes.dart';
import 'package:hive/hive.dart';
import '../models/meeting_pass.dart';

class MeetingPassRepository {
  Box<MeetingPass>? _box;

  Future<Box<MeetingPass>> _open() async =>
      _box ??= await Hive.openBox<MeetingPass>(boxMeetingPass);

  Future<void> put(MeetingPass pass) async {
    // ✅ Renamed parameter
    final box = await _open();
    await box.put(pass.passId, pass);
  }

  Future<MeetingPass?> get(String passId) async {
    final box = await _open();
    return box.get(passId);
  }

  Future<List<MeetingPass>> forMeeting(String meetingId) async {
    final box = await _open();
    return box.values
        .where((p) => p.meetingId == meetingId)
        .toList(growable: false);
  }

  Future<List<MeetingPass>> activeForMeeting(String meetingId) async {
    final box = await _open();
    return box.values
        .where((p) => p.meetingId == meetingId && !p.revoked)
        .toList(growable: false);
  }

  Future<void> revoke(String passId, {String? reason}) async {
    final box = await _open();
    final pass = box.get(passId);
    if (pass != null && !pass.revoked) {
      pass.revoked = true;
      pass.revokedReason = reason;
      await pass.save();
    }
  }

  // ✅ Check if device already has a pass for this meeting
  // Small optimization - make device check more robust:
  Future<bool> hasDevicePass(String meetingId, String deviceFingerprint) async {
    final box = await _open();
    return box.values.any(
      (p) =>
          p.meetingId == meetingId &&
          p.deviceFingerprintHash == deviceFingerprint &&
          !p.revoked &&
          // Add expiration check if needed
          p.issuedAt.isAfter(DateTime.now().subtract(Duration(hours: 12))),
    );
  }
}
