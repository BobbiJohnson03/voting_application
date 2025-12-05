import '../_boxes.dart';
import '../models/audit_log.dart';
import 'package:hive/hive.dart';

class AuditLogRepository {
  Box<AuditLog>? _box;
  Future<Box<AuditLog>> _open() async =>
      _box ??= await Hive.openBox<AuditLog>(boxAudit);

  Future<void> insert(AuditLog log) async {
    final box = await _open();
    await box.put(log.id, log); // ✅ Use id as key, not auto-increment
  }

  Future<AuditLog?> get(String id) async {
    final box = await _open();
    return box.get(id);
  }

  Future<List<AuditLog>> forSession(String sessionId) async {
    final box = await _open();
    return box.values
        .where((a) => a.sessionId == sessionId)
        .toList(growable: false);
  }

  // ✅ Added method to get last log for hash chain
  Future<AuditLog?> getLastLog() async {
    final box = await _open();
    if (box.isEmpty) return null;
    return box.values.reduce(
      (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
    );
  }

  Future<List<AuditLog>> forMeeting(String meetingId) async {
    final box = await _open();
    return box.values
        .where((a) => a.meetingId == meetingId) // ✅ Direct field access now!
        .toList(growable: false);
  }

  /// Get all audit logs
  Future<List<AuditLog>> getAll() async {
    final box = await _open();
    return box.values.toList(growable: false);
  }
}
