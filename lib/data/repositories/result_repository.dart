import '../models/result.dart';
import '_boxes.dart';
import 'package:hive/hive.dart';

class ResultRepository {
  Box<Result>? _box;
  Future<Box<Result>> _open() async =>
      _box ??= await Hive.openBox<Result>(boxResult);

  String _key(String sessionId, String questionId) => '$sessionId|$questionId';

  Future<Result?> getBySessionQuestion(
    String sessionId,
    String questionId,
  ) async {
    final box = await _open();
    return box.get(_key(sessionId, questionId));
  }

  Future<void> upsert(Result r) async {
    final box = await _open();
    await box.put(_key(r.sessionId, r.questionId), r);
  }

  Future<List<Result>> forSession(String sessionId) async {
    final box = await _open();
    return box.values
        .where((r) => r.sessionId == sessionId)
        .toList(growable: false);
  }
}
