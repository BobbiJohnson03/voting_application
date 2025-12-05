import 'package:hive/hive.dart';
import '../models/meeting.dart';
import '_boxes.dart';

class MeetingRepository {
  Box<Meeting>? _box;

  Future<Box<Meeting>> _open() async =>
      _box ??= await Hive.openBox<Meeting>(boxMeeting);

  Future<void> put(Meeting meeting) async {
    final box = await _open();
    await box.put(meeting.id, meeting);
  }

  Future<Meeting?> get(String id) async {
    final box = await _open();
    return box.get(id);
  }

  // In MeetingRepository.dart - fix this method:
  Future<Meeting?> getByJoinCode(String joinCode) async {
    final box = await _open();
    try {
      return box.values.firstWhere((meeting) => meeting.joinCode == joinCode);
    } catch (e) {
      return null;
    }
  }

  // Add to MeetingRepository.dart
  Future<List<Meeting>> getAll() async {
    final box = await _open();
    return box.values.toList(growable: false);
  }

  Future<List<Meeting>> getActive() async {
    final box = await _open();
    return box.values
        .where((meeting) => meeting.canJoin)
        .toList(growable: false);
  }

  Future<void> update(Meeting meeting) async {
    final box = await _open();
    await box.put(meeting.id, meeting);
  }

  Future<void> delete(String id) async {
    final box = await _open();
    await box.delete(id);
  }

  Future<bool> exists(String id) async {
    final box = await _open();
    return box.containsKey(id);
  }

  // New: Close a meeting and all its sessions
  Future<void> closeMeeting(String meetingId) async {
    final box = await _open();
    final meeting = box.get(meetingId);
    if (meeting != null) {
      meeting.isActive = false;
      await meeting.save();
    }
  }

  // New: Get meetings that are about to end (for notifications)
  Future<List<Meeting>> getEndingSoon({
    Duration threshold = const Duration(hours: 1),
  }) async {
    final box = await _open();
    final now = DateTime.now();
    return box.values
        .where(
          (meeting) =>
              meeting.endsAt != null &&
              meeting.endsAt!.isAfter(now) &&
              meeting.endsAt!.difference(now) <= threshold,
        )
        .toList(growable: false);
  }
}
