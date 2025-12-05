// lib/repositories/voting_repository.dart
import 'package:hive/hive.dart';
import '../models/voting.dart';
import '_boxes.dart';

class VotingRepository {
  Box<Voting>? _box;

  Future<Box<Voting>> _open() async =>
      _box ??= await Hive.openBox<Voting>(boxVoting);

  Future<void> put(Voting v) async {
    final box = await _open();
    await box.put(v.id, v);
  }

  Future<Voting?> get(String id) async {
    final box = await _open();
    return box.get(id);
  }

  Future<List<Voting>> byIds(List<String> ids) async {
    final box = await _open();
    return ids.map((id) => box.get(id)).whereType<Voting>().toList();
  }

  Future<void> update(Voting v) async {
    final box = await _open();
    await box.put(v.id, v);
  }

  Future<List<Voting>> forMeeting(String meetingId) async {
    final box = await _open();
    return box.values
        .where((v) => v.meetingId == meetingId)
        .toList(growable: false);
  }

  Future<List<Voting>> openForMeeting(String meetingId) async {
    final box = await _open();
    return box.values
        .where(
          (v) => v.meetingId == meetingId && v.canVote,
        ) // Uses canVote getter
        .toList(growable: false);
  }
}
