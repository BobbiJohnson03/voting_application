import 'package:flutter/material.dart';
import 'package:vote_app_thesis/network/api_network.dart';
import 'package:vote_app_thesis/services/device_fingerprint.dart';

class VotingPage extends StatefulWidget {
  final ApiNetwork apiNetwork;
  final String sessionId;
  final String ticketId;
  final String meetingId;
  final String? deviceFingerprint; // Optional - will generate if not provided

  const VotingPage({
    super.key,
    required this.apiNetwork,
    required this.sessionId,
    required this.ticketId,
    required this.meetingId,
    this.deviceFingerprint,
  });

  @override
  State<VotingPage> createState() => _VotingPageState();
}

class _VotingPageState extends State<VotingPage> {
  Map<String, dynamic>? _manifest;
  Map<String, String> _selectedOptions = {}; // questionId -> optionId
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _deviceFingerprint;

  @override
  void initState() {
    super.initState();
    _initFingerprint();
    _loadManifest();
  }

  Future<void> _initFingerprint() async {
    // Use provided fingerprint or generate new one
    _deviceFingerprint =
        widget.deviceFingerprint ?? await DeviceFingerprint.generate();
  }

  Future<void> _loadManifest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final manifest = await widget.apiNetwork.getManifest(widget.sessionId);
      setState(() {
        _manifest = manifest;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submitVote() async {
    if (_manifest == null) return;

    final questions = _manifest!['questions'] as List?;
    if (questions == null || questions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No questions to vote on')));
      return;
    }

    // Validate all questions are answered
    for (var question in questions) {
      final questionId = question['id'] as String?;
      if (questionId == null) continue;

      if (!_selectedOptions.containsKey(questionId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please answer all questions')),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      // Ensure we have device fingerprint
      final fingerprint =
          _deviceFingerprint ?? await DeviceFingerprint.generate();

      // Submit vote for each question
      for (var question in questions) {
        final questionId = question['id'] as String?;
        if (questionId == null) continue;

        final selectedOptionId = _selectedOptions[questionId];
        if (selectedOptionId == null) continue;

        await widget.apiNetwork.submitVote(
          ticketId: widget.ticketId,
          sessionId: widget.sessionId,
          questionId: questionId,
          selectedOptions: [selectedOptionId],
          deviceFingerprint: fingerprint,
        );
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Vote Submitted'),
            content: const Text('Your vote has been securely recorded.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to sessions
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting vote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_manifest?['title'] as String? ?? 'Voting')),
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
                    onPressed: _loadManifest,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _manifest == null
          ? const Center(child: Text('No manifest available'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _manifest!['title'] as String? ?? 'Session',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Type: ${_manifest!['type'] ?? 'unknown'}'),
                          Text('Status: ${_manifest!['status'] ?? 'unknown'}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Questions
                  ...(_buildQuestions()),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitVote,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _submitting
                          ? const CircularProgressIndicator()
                          : const Text('Submit Vote'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildQuestions() {
    final questions = _manifest!['questions'] as List?;
    if (questions == null || questions.isEmpty) {
      return [const Text('No questions available')];
    }

    return questions.asMap().entries.map((entry) {
      final index = entry.key;
      final question = entry.value as Map<String, dynamic>;
      final questionId = question['id'] as String?;
      final questionText = question['text'] as String? ?? 'Question';
      final options = question['options'] as List? ?? [];

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${index + 1}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(questionText, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              ...options.map((option) {
                final optionId = option['id'] as String?;
                final optionText = option['text'] as String? ?? 'Option';
                final isSelected =
                    questionId != null &&
                    _selectedOptions[questionId] == optionId;

                return RadioListTile<String>(
                  title: Text(optionText),
                  value: optionId ?? '',
                  groupValue: questionId != null
                      ? _selectedOptions[questionId]
                      : null,
                  onChanged: questionId != null
                      ? (value) {
                          setState(() {
                            _selectedOptions[questionId] = value ?? '';
                          });
                        }
                      : null,
                  selected: isSelected,
                );
              }),
            ],
          ),
        ),
      );
    }).toList();
  }
}
