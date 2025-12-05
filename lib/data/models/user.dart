import 'package:hive/hive.dart';
import 'package:vote_app_thesis/models/enums.dart';
part 'user.g.dart';

@HiveType(typeId: 15)
class HiveUser extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String username;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final UserRole role;

  @HiveField(4)
  final bool isActive;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime? lastLoginAt;

  @HiveField(7)
  final String? deviceFingerprint;

  HiveUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
    this.deviceFingerprint,
  });

  HiveUser copyWith({
    String? id,
    String? username,
    String? email,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? deviceFingerprint,
  }) {
    return HiveUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
    );
  }
}
