import "package:vote_app_thesis/models/enums.dart";
import 'package:hive/hive.dart';
part 'voting.g.dart';

@HiveType(typeId: 8)
class Voting extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  VotingType type;

  @HiveField(3)
  AnswersSchema answersSchema;

  @HiveField(4)
  List<String> questionIds;

  @HiveField(5)
  VotingStatus status; // Single source of truth

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? endsAt; // Combined: voting ends + voting expires

  @HiveField(8)
  String jwtKeyId;

  @HiveField(9)
  String? ledgerHeadHash;

  @HiveField(10)
  String joinCode;

  @HiveField(11)
  String meetingId;

  @HiveField(12)
  int durationMinutes; // How long voting will be open (in minutes)

  Voting({
    required this.id,
    required this.title,
    required this.type,
    required this.answersSchema,
    this.questionIds = const [],
    this.status = VotingStatus.open,
    required this.createdAt,
    this.endsAt,
    required this.jwtKeyId,
    this.ledgerHeadHash,
    this.joinCode = '',
    required this.meetingId,
    this.durationMinutes = 15, // Default 15 minutes
  });

  // Simplified logic:
  bool get canVote =>
      status == VotingStatus.open &&
      (endsAt == null || DateTime.now().isBefore(endsAt!));

  bool get canView => status != VotingStatus.archived;

  /// Open the voting (admin activates it)
  /// Uses the durationMinutes field set during creation
  void open() {
    status = VotingStatus.open;
    if (durationMinutes > 0) {
      endsAt = DateTime.now().add(Duration(minutes: durationMinutes));
    }
    save();
  }

  void close() {
    status = VotingStatus.closed;
    save();
  }

  /// Mark voting as ready for score viewing (results published)
  void showScore() {
    status = VotingStatus.score;
    save();
  }

  void archive() {
    status = VotingStatus.archived;
    save();
  }

  /// Check if results can be viewed (score status)
  bool get canViewResults => status == VotingStatus.score;
}
