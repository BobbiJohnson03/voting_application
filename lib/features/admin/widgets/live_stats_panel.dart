import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/server_service.dart';

/// Live statistics panel that auto-refreshes every few seconds
class LiveStatsPanel extends StatefulWidget {
  final ServerService serverService;
  final String meetingId;
  final Duration refreshInterval;

  const LiveStatsPanel({
    super.key,
    required this.serverService,
    required this.meetingId,
    this.refreshInterval = const Duration(seconds: 5),
  });

  @override
  State<LiveStatsPanel> createState() => _LiveStatsPanelState();
}

class _LiveStatsPanelState extends State<LiveStatsPanel> {
  Timer? _refreshTimer;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    try {
      final stats = await widget.serverService.getStats(widget.meetingId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _stats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null && _stats == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final joinedDevices = _stats?['joinedDevices'] ?? 0;
    final totalVotes = _stats?['totalVotes'] ?? 0;
    final votings = (_stats?['votings'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with refresh indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📊 Live Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (_loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadStats,
                      tooltip: 'Refresh now',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),

            // Main stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBox(
                  icon: Icons.devices,
                  label: 'Joined',
                  value: joinedDevices.toString(),
                  color: Colors.blue,
                ),
                _StatBox(
                  icon: Icons.how_to_vote,
                  label: 'Total Votes',
                  value: totalVotes.toString(),
                  color: Colors.green,
                ),
                _StatBox(
                  icon: Icons.ballot,
                  label: 'Votings',
                  value: votings.length.toString(),
                  color: Colors.orange,
                ),
              ],
            ),

            // Voting details
            if (votings.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Voting Sessions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...votings.map((v) => _VotingStatTile(voting: v)),
            ],

            // Last update time
            const SizedBox(height: 12),
            Text(
              'Last update: ${_formatTime(_stats?['timestamp'])}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return 'Unknown';
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _VotingStatTile extends StatelessWidget {
  final Map<String, dynamic> voting;

  const _VotingStatTile({required this.voting});

  @override
  Widget build(BuildContext context) {
    final title = voting['title'] ?? 'Unknown';
    final status = voting['status'] ?? 'unknown';
    final votesSubmitted = voting['votesSubmitted'] ?? 0;
    final ticketsIssued = voting['ticketsIssued'] ?? 0;
    final canVote = voting['canVote'] ?? false;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'open':
        statusColor = Colors.green;
        statusIcon = Icons.play_circle;
        break;
      case 'closed':
        statusColor = Colors.red;
        statusIcon = Icons.stop_circle;
        break;
      case 'score':
        statusColor = Colors.blue;
        statusIcon = Icons.leaderboard;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Status: ${status.toUpperCase()}${canVote ? ' (accepting votes)' : ''}',
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$votesSubmitted votes',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '$ticketsIssued tickets',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
