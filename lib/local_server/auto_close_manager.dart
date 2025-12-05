import 'dart:async';
import '../repositories/meeting_repository.dart';
import '../repositories/voting_repository.dart';
import 'broadcast_manager.dart';

class AutoCloseManager {
  final MeetingRepository meetings;
  final VotingRepository votings;
  final BroadcastManager broadcast;

  Timer? _timer;

  AutoCloseManager(this.meetings, this.votings, this.broadcast);

  void start() {
    stop();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final all = await meetings.getAll(); // ✅ CHANGED: .all() to .getAll()
      for (final m in all) {
        for (final sid in m.sessionIds) {
          final v = await votings.get(sid);
          if (v != null &&
              v.canVote &&
              v.endsAt != null &&
              DateTime.now().isAfter(v.endsAt!)) {
            v.close();
            broadcast.send(m.id, {'type': 'voting_closed', 'votingId': sid});
          }
        }
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
