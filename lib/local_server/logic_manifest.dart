import 'package:shelf/shelf.dart';
import '../repositories/voting_repository.dart';
import '../repositories/question_repository.dart';
import 'logic_helpers.dart';

class LogicManifest {
  final VotingRepository votings;
  final QuestionRepository questions;

  LogicManifest({required this.votings, required this.questions});

  Future<Response> manifest(Request req) async {
    final sessionId = req.requestedUri.queryParameters['sessionId']?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      return jsonErr('Missing sessionId', status: 400);
    }

    final voting = await votings.get(sessionId);
    if (voting == null) {
      return jsonErr('Voting not found', status: 404);
    }

    final questionsList = await questions.byIds(voting.questionIds);
    final questionsJson = [
      for (final question in questionsList)
        {
          'id': question.id,
          'text': question.text,
          'maxSelections': question.maxSelections,
          'displayOrder': question.displayOrder,
          'options': [
            for (final option in question.options)
              {'id': option.id, 'text': option.text},
          ],
        },
    ];

    return jsonOk({
      'sessionId': voting.id,
      'title': voting.title,
      'type': voting.type.name,
      'answersSchema': voting.answersSchema.name,
      'status': voting.status.name,
      'canVote': voting.canVote,
      'endsAt': voting.endsAt?.toIso8601String(),
      'questions': questionsJson,
    });
  }
}
