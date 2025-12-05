import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/server_service.dart';
import '../../../core/network/api_network.dart';
import '../../../data/models/meeting.dart';
import '../../../data/models/voting.dart';
import '../../../data/models/enums.dart';
import 'session_results_page.dart';

/// Archive page showing past meetings and their voting results
class ArchivePage extends StatefulWidget {
  final ServerService serverService;
  final ApiNetwork apiNetwork;

  const ArchivePage({
    super.key,
    required this.serverService,
    required this.apiNetwork,
  });

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Meeting> _meetings = [];
  Map<String, List<Voting>> _votingsByMeeting = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load all meetings
      final meetings = await widget.serverService.meetings.getAll();
      
      // Sort by createdAt descending (newest first)
      meetings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Load votings for each meeting
      final votingsByMeeting = <String, List<Voting>>{};
      for (final meeting in meetings) {
        final votings = await widget.serverService.votings.forMeeting(meeting.id);
        // Sort votings by createdAt descending
        votings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        votingsByMeeting[meeting.id] = votings;
      }

      setState(() {
        _meetings = meetings;
        _votingsByMeeting = votingsByMeeting;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _viewResults(String sessionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsPage(
          apiNetwork: widget.apiNetwork,
          sessionId: sessionId,
          serverService: widget.serverService,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  Color _getStatusColor(VotingStatus status) {
    switch (status) {
      case VotingStatus.open:
        return Colors.green;
      case VotingStatus.closed:
        return Colors.orange;
      case VotingStatus.score:
        return Colors.blue;
      case VotingStatus.archived:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(VotingStatus status) {
    switch (status) {
      case VotingStatus.open:
        return Icons.play_circle;
      case VotingStatus.closed:
        return Icons.stop_circle;
      case VotingStatus.score:
        return Icons.leaderboard;
      case VotingStatus.archived:
        return Icons.archive;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadArchive,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadArchive,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _meetings.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No meetings found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create a meeting to get started',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _meetings.length,
                      itemBuilder: (context, index) {
                        final meeting = _meetings[index];
                        final votings = _votingsByMeeting[meeting.id] ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: meeting.isActive
                                  ? Colors.green
                                  : Colors.grey,
                              child: Icon(
                                meeting.isActive
                                    ? Icons.meeting_room
                                    : Icons.meeting_room_outlined,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              meeting.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateTime(meeting.createdAt),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.vpn_key, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Code: ${meeting.joinCode}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.how_to_vote, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${votings.length} voting${votings.length == 1 ? '' : 's'}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            children: votings.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No votings in this meeting',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ]
                                : votings.map((voting) {
                                    return ListTile(
                                      leading: Icon(
                                        _getStatusIcon(voting.status),
                                        color: _getStatusColor(voting.status),
                                      ),
                                      title: Text(voting.title),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                size: 8,
                                                color: _getStatusColor(voting.status),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                voting.status.name.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _getStatusColor(voting.status),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '• ${voting.type.name}',
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Created: ${_formatDateTime(voting.createdAt)}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          if (voting.endsAt != null)
                                            Text(
                                              'Ends: ${_formatDateTime(voting.endsAt!)}',
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.bar_chart),
                                        onPressed: () => _viewResults(voting.id),
                                        tooltip: 'View Results',
                                      ),
                                      onTap: () => _viewResults(voting.id),
                                    );
                                  }).toList(),
                          ),
                        );
                      },
                    ),
    );
  }
}
