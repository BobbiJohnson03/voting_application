import 'package:flutter/material.dart';
import 'package:vote_app_thesis/network/api_network.dart';
import 'package:vote_app_thesis/services/export_service.dart';
// import 'package:vote_app_thesis/services/print_service.dart';  // Temporarily disabled
import 'package:vote_app_thesis/services/server_service.dart';
import 'package:vote_app_thesis/models/voting.dart';
import 'package:vote_app_thesis/models/meeting.dart';
import 'package:vote_app_thesis/models/question.dart';
import 'package:vote_app_thesis/models/enums.dart';

class ResultsPage extends StatefulWidget {
  final ApiNetwork apiNetwork;
  final String? sessionId;
  final ServerService? serverService; // Optional - for fetching real data

  const ResultsPage({
    super.key,
    required this.apiNetwork,
    this.sessionId,
    this.serverService,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  Map<String, dynamic>? _results;
  bool _loading = true;
  String? _error;

  // Cached data for export
  Voting? _voting;
  Meeting? _meeting;
  List<Question> _questions = [];

  // Export service
  late final ExportService _exportService = ExportService();
  // late final PrintService _printService = PrintService();  // Temporarily disabled

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      _loadResults();
    } else {
      setState(() {
        _loading = false;
        _error = 'No session ID provided';
      });
    }
  }

  Future<void> _loadResults() async {
    if (widget.sessionId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await widget.apiNetwork.getResults(widget.sessionId!);

      // Load session, meeting, and questions from ServerService if available
      if (widget.serverService != null) {
        final voting = await widget.serverService!.votings.get(
          widget.sessionId!,
        );
        if (voting != null) {
          _voting = voting;
          _meeting = await widget.serverService!.meetings.get(voting.meetingId);
          _questions = await widget.serverService!.questions.byIds(
            voting.questionIds,
          );
        }
      }

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Handle export menu selection
  Future<void> _handleExport(String format) async {
    if (_results == null || widget.sessionId == null) return;

    try {
      // Use cached data if available, otherwise create fallback
      final meeting =
          _meeting ??
          Meeting(
            id: 'meeting-unknown',
            title: 'Meeting',
            joinCode: '',
            createdAt: DateTime.now(),
          );

      final voting =
          _voting ??
          Voting(
            id: widget.sessionId!,
            title: 'Voting ${widget.sessionId!}',
            type: VotingType.nonsecret,
            answersSchema: AnswersSchema.custom,
            createdAt: DateTime.now(),
            jwtKeyId: 'key-1',
            meetingId: meeting.id,
          );

      // Convert results to expected format
      final resultsData = _results!['results'] as Map<String, dynamic>? ?? {};
      final formattedResults = <String, Map<String, int>>{};

      resultsData.forEach((questionId, questionData) {
        if (questionData is Map<String, dynamic>) {
          final options = <String, int>{};
          questionData.forEach((optionId, votes) {
            options[optionId] = votes as int? ?? 0;
          });
          formattedResults[questionId] = options;
        }
      });

      switch (format) {
        case 'csv':
          await _exportService.exportToCSV(
            voting,
            formattedResults,
            meeting,
            questions: _questions,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV exported successfully')),
            );
          }
          break;
        case 'pdf':
          // Use cached questions or empty list
          await _exportService.exportToPDF(
            voting,
            formattedResults,
            meeting,
            _questions,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF exported successfully')),
            );
          }
          break;
        case 'print':
          // Print functionality temporarily disabled
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Print functionality temporarily disabled'),
            ),
          );
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voting Results'),
        actions: [
          if (widget.sessionId != null) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadResults,
              tooltip: 'Refresh',
            ),
            PopupMenuButton<String>(
              onSelected: _handleExport,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 8),
                      Text('Export CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf),
                      SizedBox(width: 8),
                      Text('Export PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'print',
                  child: Row(
                    children: [
                      Icon(Icons.print),
                      SizedBox(width: 8),
                      Text('Print'),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
                  Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadResults,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _results == null
          ? const Center(child: Text('No results available'))
          : _buildResults(),
    );
  }

  Widget _buildResults() {
    final resultsData = _results!['results'] as Map<String, dynamic>?;
    if (resultsData == null || resultsData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No votes yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Results for each question
        ...resultsData.entries.map((entry) {
          final questionId = entry.key;
          final optionTallies = entry.value as Map<String, dynamic>?;
          if (optionTallies == null) return const SizedBox.shrink();

          // Calculate total votes
          final totalVotes = optionTallies.values.fold<int>(
            0,
            (sum, count) => sum + (count as int? ?? 0),
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question: $questionId',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Votes: $totalVotes',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  // Results for each option
                  ...optionTallies.entries.map((optionEntry) {
                    final optionId = optionEntry.key;
                    final voteCount = optionEntry.value as int? ?? 0;
                    final percentage = totalVotes > 0
                        ? (voteCount / totalVotes * 100).toStringAsFixed(1)
                        : '0.0';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  optionId,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                '$voteCount votes ($percentage%)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: totalVotes > 0 ? voteCount / totalVotes : 0,
                            backgroundColor: Colors.grey[300],
                            minHeight: 8,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
