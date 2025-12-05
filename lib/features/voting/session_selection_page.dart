import 'package:flutter/material.dart';
import '../../core/network/api_network.dart';
import '../../core/services/device_fingerprint.dart';
import 'voting_page.dart';
import '../admin/pages/session_results_page.dart';

class SessionsSelectionPage extends StatefulWidget {
  final ApiNetwork apiNetwork;
  final String meetingId;
  final String meetingPassId;
  final String meetingTitle;
  final List<Map<String, dynamic>> initialSessions;
  final String? serverUrl;

  const SessionsSelectionPage({
    super.key,
    required this.apiNetwork,
    required this.meetingId,
    required this.meetingPassId,
    required this.meetingTitle,
    this.initialSessions = const [],
    this.serverUrl,
  });

  factory SessionsSelectionPage.withManualData({
    required ApiNetwork apiNetwork,
    required Map<String, dynamic> manualData,
  }) {
    final serverUrl = manualData['serverUrl'] as String?;
    final updatedApiNetwork = serverUrl != null
        ? ApiNetwork(serverUrl)
        : apiNetwork;

    final meetingId = manualData['meetingId'] as String;
    final joinCode = manualData['joinCode'] as String? ?? '';

    return SessionsSelectionPage(
      apiNetwork: updatedApiNetwork,
      meetingId: meetingId,
      // For manual mode you decided to reuse meetingId as passId
      meetingPassId: meetingId,
      meetingTitle: 'Manual Entry Meeting ($joinCode)',
      initialSessions: const [],
      serverUrl: serverUrl,
    );
  }

  @override
  State<SessionsSelectionPage> createState() => _SessionsSelectionPageState();
}

class _SessionsSelectionPageState extends State<SessionsSelectionPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.initialSessions);

    // If this is manual entry or we have a remote server, fetch sessions
    if (widget.serverUrl != null) {
      _fetchSessions();
    }
  }

  Future<void> _fetchSessions() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      // Fetch manifest/sessions list from server
      // You implemented a generic GET on ApiNetwork.
      final response = await widget.apiNetwork.get('/manifest');

      if (response['success'] == true && response['sessions'] != null) {
        final sessions = List<Map<String, dynamic>>.from(
          response['sessions'] as List,
        );

        // Filter sessions: show open, closed, and score (exclude only archived)
        final visibleSessions = sessions.where((session) {
          final status = session['status'] as String?;
          return status != 'archived';
        }).toList();

        if (mounted) {
          setState(() {
            _sessions = visibleSessions;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching sessions: $e')));
      }
    }
  }

  Future<void> _joinSession(Map<String, dynamic> session) async {
    try {
      // Get device fingerprint
      final deviceFingerprint = await DeviceFingerprint.generate();

      // Request ticket
      final ticketResponse = await widget.apiNetwork.requestTicket(
        meetingPassId: widget.meetingPassId,
        sessionId: session['id'] as String,
        deviceFingerprint: deviceFingerprint,
      );

      final ticketId = ticketResponse['ticketId'] as String?;
      final sessionId = ticketResponse['sessionId'] as String?;

      if (ticketId == null || sessionId == null) {
        throw Exception('Failed to get voting ticket');
      }

      // Navigate to voting page with the same device fingerprint used for ticket
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VotingPage(
              apiNetwork: widget.apiNetwork,
              sessionId: sessionId,
              ticketId: ticketId,
              meetingId: widget.meetingId,
              deviceFingerprint: deviceFingerprint,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewResults(String sessionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ResultsPage(apiNetwork: widget.apiNetwork, sessionId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.meetingTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No active sessions available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Wait for the admin to create a session',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _sessions.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final session = _sessions[index];
                final status = session['status'] as String? ?? 'unknown';
                final canVote = status == 'open';
                final isScore = status == 'score';
                final isClosed = status == 'closed';

                // Determine icon and color based on status
                IconData icon;
                Color iconColor;
                if (canVote) {
                  icon = Icons.how_to_vote;
                  iconColor = Colors.green;
                } else if (isScore) {
                  icon = Icons.bar_chart;
                  iconColor = Colors.blue;
                } else {
                  icon = Icons.lock;
                  iconColor = Colors.grey;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  // Dim the card for closed sessions
                  color: isClosed ? Colors.grey[200] : null,
                  child: ListTile(
                    leading: Icon(icon, color: iconColor),
                    title: Text(
                      session['title'] as String? ?? 'Unknown Session',
                      style: TextStyle(color: isClosed ? Colors.grey : null),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type: ${session['type'] ?? 'unknown'}',
                          style: TextStyle(
                            color: isClosed ? Colors.grey : null,
                          ),
                        ),
                        Text(
                          'Status: $status',
                          style: TextStyle(
                            color: isClosed ? Colors.grey : null,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (session['endsAt'] != null)
                          Text(
                            'Ends: ${session['endsAt']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isClosed ? Colors.grey : null,
                            ),
                          ),
                        if (isClosed)
                          const Text(
                            'Voting closed - awaiting results',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (isScore)
                          const Text(
                            'Results available - tap to view',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    trailing: canVote
                        ? const Icon(Icons.arrow_forward, color: Colors.green)
                        : isScore
                        ? const Icon(Icons.visibility, color: Colors.blue)
                        : const Icon(Icons.lock, color: Colors.grey),
                    onTap: canVote
                        ? () => _joinSession(session)
                        : isScore
                        ? () => _viewResults(session['id'] as String)
                        : null,
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
