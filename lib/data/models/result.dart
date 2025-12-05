import 'package:hive/hive.dart';
part 'result.g.dart';

@HiveType(typeId: 12)
class Result extends HiveObject {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final String questionId;

  @HiveField(2)
  final Map<String, int> optionVotes; // countsByOptionId

  @HiveField(3)
  final DateTime computedAt;

  @HiveField(4)
  final int totalVotes;

  Result({
    required this.sessionId,
    required this.questionId,
    required this.optionVotes,
    required this.computedAt,
  }) : totalVotes = optionVotes.values.fold(0, (sum, count) => sum + count);
}
