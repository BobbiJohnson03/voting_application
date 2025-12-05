import 'package:hive/hive.dart';
part 'signing_key.g.dart';

@HiveType(typeId: 9)
class SigningKey extends HiveObject {
  @HiveField(0)
  String keyId;

  @HiveField(1)
  String sessionId;

  @HiveField(2)
  String kty; // 'HMAC'

  @HiveField(3)
  String secret; // lokalny sekret

  @HiveField(4)
  DateTime createdAt;

  SigningKey({
    required this.keyId,
    required this.sessionId,
    this.kty = 'HMAC',
    required this.secret,
    required this.createdAt,
  });
}
