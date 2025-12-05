import 'package:shelf/shelf.dart';
import '../data/repositories/voting_repository.dart';
import '../data/repositories/question_repository.dart';
import 'logic_helpers.dart';

class LogicManifest {
  final VotingRepository votings;
  final QuestionRepository questions;

  LogicManifest({required this.votings, required this.questions});

  /// Get list of sessions for a meeting (for client refresh)
  Future<Response> sessions(Request req) async {
    final meetingId = req.requestedUri.queryParameters['meetingId']?.trim();
    if (meetingId == null || meetingId.isEmpty) {
      return jsonErr('Missing meetingId', status: 400);
    }

    final allVotings = await votings.forMeeting(meetingId);
    
    // Return all non-archived sessions
    final visibleVotings = allVotings.where((v) => v.status.name != 'archived');
    
    return jsonOk({
      'success': true,
      'sessions': visibleVotings.map((v) => {
        'id': v.id,
        'title': v.title,
        'status': v.status.name,
        'type': v.type.name,
        'canVote': v.canVote,
        'endsAt': v.endsAt?.toIso8601String(),
      }).toList(),
    });
  }

  /// Get details of a single voting session
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
