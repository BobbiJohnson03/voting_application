import 'package:hive/hive.dart';
part 'meeting.g.dart';

@HiveType(typeId: 5)
class Meeting extends HiveObject {
  @HiveField(0)
  final String id; // Renamed from meetingId for consistency

  @HiveField(1)
  String title;

  @HiveField(2)
  List<String> sessionIds;

  @HiveField(3)
  bool isActive; // More descriptive than isOpen

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? endsAt;

  @HiveField(6)
  String joinCode; // Renamed from shortCode

  Meeting({
    required this.id,
    required this.title,
    this.sessionIds = const [],
    this.isActive = true,
    required this.createdAt,
    this.endsAt,
    this.joinCode = '',
  });

  bool get isOver => endsAt != null && DateTime.now().isAfter(endsAt!);

  // Add this for better UX:
  bool get canJoin => isActive && !isOver;
}
