import '../_boxes.dart';
import '../models/signing_key.dart';
import 'package:hive/hive.dart';

class SigningKeyRepository {
  Box<SigningKey>? _box;
  Future<Box<SigningKey>> _open() async =>
      _box ??= await Hive.openBox<SigningKey>(boxSigningKey);

  Future<void> put(SigningKey k) async {
    final box = await _open();
    await box.put(k.keyId, k);
  }

  Future<SigningKey?> get(String keyId) async {
    final box = await _open();
    return box.get(keyId);
  }

  Future<List<SigningKey>> forSession(String sessionId) async {
    final box = await _open();
    return box.values
        .where((k) => k.sessionId == sessionId)
        .toList(growable: false);
  }
}
