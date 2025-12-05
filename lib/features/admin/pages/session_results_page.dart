import 'package:flutter/material.dart';
import '../../../core/network/api_network.dart';
import '../../../core/services/export_service.dart';
// import '../../../core/services/print_service.dart';  // Temporarily disabled
import '../../../core/services/server_service.dart';
import '../../../data/models/voting.dart';
import '../../../data/models/meeting.dart';
import '../../../data/models/question.dart';
import '../../../data/models/enums.dart';

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

    // Header with session info
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Session header
        if (_voting != null) ...[
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.how_to_vote, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _voting!.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total responses: ${_results!['totalVotes'] ?? 0}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Results for each question
        ...resultsData.entries.toList().asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final entry = mapEntry.value;
          final questionId = entry.key;
          final optionTallies = entry.value as Map<String, dynamic>?;
          if (optionTallies == null) return const SizedBox.shrink();

          // Find question by ID to get text
          final question = _questions.where((q) => q.id == questionId).firstOrNull;
          final questionText = question?.text ?? 'Question ${index + 1}';

          // Calculate total votes for this question
          final totalVotes = optionTallies.values.fold<int>(
            0,
            (sum, count) => sum + (count as int? ?? 0),
          );

          // Sort options by vote count (descending)
          final sortedOptions = optionTallies.entries.toList()
            ..sort((a, b) => (b.value as int).compareTo(a.value as int));

          // Find max votes for scaling
          final maxVotes = sortedOptions.isNotEmpty
              ? sortedOptions.first.value as int
              : 1;

          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Q${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          questionText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Results bar chart
                  ...sortedOptions.map((optionEntry) {
                    final optionId = optionEntry.key;
                    final voteCount = optionEntry.value as int;
                    final percentage = totalVotes > 0
                        ? (voteCount / totalVotes * 100)
                        : 0.0;

                    // Find option text
                    final option = question?.options
                        .where((o) => o.id == optionId)
                        .firstOrNull;
                    final optionText = option?.text ?? optionId;

                    // Color based on ranking
                    final isWinner = voteCount == maxVotes && voteCount > 0;
                    final barColor = isWinner ? Colors.green : Colors.blue;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Option text and votes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (isWinner)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.emoji_events,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        optionText,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isWinner
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$voteCount (${percentage.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: barColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Progress bar
                          Stack(
                            children: [
                              Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: totalVotes > 0
                                    ? voteCount / totalVotes
                                    : 0,
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        barColor,
                                        barColor.withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
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
