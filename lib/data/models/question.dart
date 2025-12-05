import "package:vote_app_thesis/models/option.dart";
import "package:vote_app_thesis/models/enums.dart";
import 'package:hive/hive.dart';
part 'question.g.dart';

/* pojedyncze pytanie; admin tworzy kilka takich pytań i grupuje je następnie w Session */
@HiveType(typeId: 7)
class Question extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String text;

  @HiveField(2)
  List<Option> options;

  @HiveField(3)
  int maxSelections; // How many options user can select (1 for yesNo/yesNoAbstain, N for custom)

  @HiveField(4)
  int displayOrder;

  @HiveField(5)
  String sessionId;

  @HiveField(6)
  AnswersSchema answerSchema; // Each question has its own type!

  Question({
    required this.id,
    required this.text,
    required this.options,
    this.maxSelections = 1,
    this.displayOrder = 0,
    required this.sessionId,
    this.answerSchema = AnswersSchema.yesNoAbstain,
  });
}
