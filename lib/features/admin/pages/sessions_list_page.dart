import 'package:flutter/material.dart';
import '../../../core/network/api_network.dart';
import '../../../core/services/server_service.dart';
import '../../../data/models/voting.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/meeting.dart';
import 'create_session_page.dart';
import 'session_results_page.dart';

class SessionsListPage extends StatefulWidget {
  final String meetingId;
  final ServerService serverService;
  final ApiNetwork apiNetwork;

  const SessionsListPage({
    super.key,
    required this.meetingId,
    required this.serverService,
    required this.apiNetwork,
  });

  @override
  State<SessionsListPage> createState() => _SessionsListPageState();
}

class _SessionsListPageState extends State<SessionsListPage> {
  List<Voting> _votings = [];
  Meeting? _meeting;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final meeting = await widget.serverService.meetings.get(widget.meetingId);
      final votings = await widget.serverService.votings.forMeeting(
        widget.meetingId,
      );
      setState(() {
        _meeting = meeting;
        _votings = votings;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _openVoting(Voting voting) async {
    try {
      voting.open(); // Opens voting and sets endsAt based on durationMinutes
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Voting opened! Ends in ${voting.durationMinutes} minutes',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening voting: $e')));
      }
    }
  }

  Future<void> _closeVoting(String votingId) async {
    try {
      await widget.apiNetwork.adminClose(votingId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Voting closed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error closing voting: $e')));
      }
    }
  }

  Future<void> _publishResults(Voting voting) async {
    try {
      voting.showScore();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Results published! Participants can now view scores.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error publishing results: $e')));
      }
    }
  }

  void _navigateToCreateVoting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSessionPage(
          meetingId: widget.meetingId,
          serverService: widget.serverService,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _viewResults(String votingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsPage(
          apiNetwork: widget.apiNetwork,
          sessionId: votingId,
          serverService: widget.serverService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_meeting?.title ?? 'Votings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreateVoting,
            tooltip: 'Create Voting',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _votings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No votings yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _navigateToCreateVoting,
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Voting'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _votings.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final voting = _votings[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: ListTile(
                            leading: Icon(
                              voting.status == VotingStatus.open
                                  ? Icons.how_to_vote
                                  : voting.status == VotingStatus.closed
                                  ? Icons.check_circle
                                  : voting.status == VotingStatus.score
                                  ? Icons.bar_chart
                                  : Icons.archive,
                              color: voting.status == VotingStatus.open
                                  ? Colors.green
                                  : voting.status == VotingStatus.closed
                                  ? Colors.orange
                                  : voting.status == VotingStatus.score
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            title: Text(voting.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Type: ${voting.type.name}'),
                                Text('Status: ${voting.status.name}'),
                                // Show duration for closed votings, end time for open votings
                                if (voting.status == VotingStatus.closed)
                                  Text(
                                    'Duration: ${voting.durationMinutes} min (not started)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                if (voting.status == VotingStatus.open &&
                                    voting.endsAt != null)
                                  Text(
                                    'Ends: ${_formatDate(voting.endsAt!)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                Text(
                                  'Questions: ${voting.questionIds.length}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Open button for closed votings
                                if (voting.status == VotingStatus.closed)
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () => _openVoting(voting),
                                    tooltip:
                                        'Open Voting (${voting.durationMinutes} min)',
                                    color: Colors.green,
                                  ),
                                // Close button for open votings
                                if (voting.status == VotingStatus.open)
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => _closeVoting(voting.id),
                                    tooltip: 'Close Voting',
                                    color: Colors.red,
                                  ),
                                // Publish results button for closed votings
                                if (voting.status == VotingStatus.closed)
                                  IconButton(
                                    icon: const Icon(Icons.publish),
                                    onPressed: () => _publishResults(voting),
                                    tooltip: 'Publish Results',
                                    color: Colors.blue,
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.bar_chart),
                                  onPressed: () => _viewResults(voting.id),
                                  tooltip: 'View Results',
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateVoting,
        child: const Icon(Icons.add),
        tooltip: 'Create Voting',
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
