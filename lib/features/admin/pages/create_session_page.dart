import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vote_app_thesis/services/server_service.dart';
import 'package:vote_app_thesis/models/voting.dart';
import 'package:vote_app_thesis/models/question.dart';
import 'package:vote_app_thesis/models/option.dart';
import 'package:vote_app_thesis/models/signing_key.dart';
import 'package:vote_app_thesis/models/enums.dart';
import 'package:uuid/uuid.dart';

class CreateSessionPage extends StatefulWidget {
  final String meetingId;
  final ServerService serverService;

  const CreateSessionPage({
    super.key,
    required this.meetingId,
    required this.serverService,
  });

  @override
  State<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends State<CreateSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final Uuid _uuid = Uuid();

  VotingType _votingType = VotingType.secret;
  final TextEditingController _durationController = TextEditingController(
    text: '15',
  );
  int _durationMinutes = 15;

  List<QuestionData> _questions = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    for (var q in _questions) {
      q.textController.dispose();
      for (var o in q.options) {
        o.textController.dispose();
      }
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        QuestionData(
          id: _uuid.v4(),
          textController: TextEditingController(),
          answerSchema: AnswersSchema.yesNoAbstain,
          maxSelections: 1,
          options: [],
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      final question = _questions[index];
      question.textController.dispose();
      for (var option in question.options) {
        option.textController.dispose();
      }
      _questions.removeAt(index);
    });
  }

  void _addOption(int questionIndex) {
    setState(() {
      _questions[questionIndex].options.add(
        OptionData(id: _uuid.v4(), textController: TextEditingController()),
      );
    });
  }

  void _removeOption(int questionIndex, int optionIndex) {
    setState(() {
      final option = _questions[questionIndex].options[optionIndex];
      option.textController.dispose();
      _questions[questionIndex].options.removeAt(optionIndex);
    });
  }

  /// Change question type and update options accordingly
  void _changeQuestionType(int questionIndex, AnswersSchema newSchema) {
    setState(() {
      final question = _questions[questionIndex];

      // Dispose old options
      for (var option in question.options) {
        option.textController.dispose();
      }
      question.options.clear();

      question.answerSchema = newSchema;

      // For yesNo and yesNoAbstain, maxSelections is always 1
      if (newSchema != AnswersSchema.custom) {
        question.maxSelections = 1;
      }
    });
  }

  /// Get options for non-custom question types
  List<Option> _getStandardOptions(AnswersSchema schema) {
    switch (schema) {
      case AnswersSchema.yesNo:
        return [
          Option(id: _uuid.v4(), text: 'Yes'),
          Option(id: _uuid.v4(), text: 'No'),
        ];
      case AnswersSchema.yesNoAbstain:
        return [
          Option(id: _uuid.v4(), text: 'Yes'),
          Option(id: _uuid.v4(), text: 'No'),
          Option(id: _uuid.v4(), text: 'Abstain'),
        ];
      case AnswersSchema.custom:
        return [];
    }
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    // Validate questions
    for (var i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      if (question.textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question ${i + 1} must have text')),
        );
        return;
      }

      // For custom questions, validate options
      if (question.answerSchema == AnswersSchema.custom) {
        if (question.options.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Question ${i + 1} (custom) must have at least one option',
              ),
            ),
          );
          return;
        }
        for (var j = 0; j < question.options.length; j++) {
          if (question.options[j].textController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Question ${i + 1}, Option ${j + 1} must have text',
                ),
              ),
            );
            return;
          }
        }
        if (question.maxSelections > question.options.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Question ${i + 1}: Max selections cannot exceed number of options',
              ),
            ),
          );
          return;
        }
      }
    }

    setState(() => _saving = true);

    try {
      // Create signing key for session
      final keyId = _uuid.v4();
      final secret = _generateSecret();
      final signingKey = SigningKey(
        keyId: keyId,
        sessionId: '',
        kty: 'HMAC',
        secret: secret,
        createdAt: DateTime.now(),
      );

      // Create session
      final sessionId = _uuid.v4();
      final voting = Voting(
        id: sessionId,
        title: _titleController.text.trim(),
        type: _votingType,
        answersSchema: AnswersSchema
            .custom, // Not used anymore - each question has its own
        questionIds: [],
        status: VotingStatus.closed,
        createdAt: DateTime.now(),
        endsAt: null,
        jwtKeyId: keyId,
        meetingId: widget.meetingId,
        joinCode: _uuid.v4().substring(0, 6).toUpperCase(),
        durationMinutes: _durationMinutes,
      );

      signingKey.sessionId = sessionId;

      // Create questions and options
      final questionIds = <String>[];
      for (var i = 0; i < _questions.length; i++) {
        final questionData = _questions[i];
        final questionId = questionData.id;

        // Get options based on question type
        List<Option> options;
        if (questionData.answerSchema == AnswersSchema.custom) {
          // Custom: use user-defined options
          options = questionData.options.map((optionData) {
            return Option(
              id: optionData.id,
              text: optionData.textController.text.trim(),
            );
          }).toList();
        } else {
          // yesNo or yesNoAbstain: auto-generate standard options
          options = _getStandardOptions(questionData.answerSchema);
        }

        // Create question with its own answer schema
        final question = Question(
          id: questionId,
          text: questionData.textController.text.trim(),
          options: options,
          maxSelections: questionData.maxSelections,
          displayOrder: i,
          sessionId: sessionId,
          answerSchema: questionData.answerSchema,
        );

        await widget.serverService.questions.put(question);
        questionIds.add(questionId);
      }

      // Update voting with question IDs
      voting.questionIds = questionIds;
      await widget.serverService.votings.put(voting);
      await widget.serverService.signingKeys.put(signingKey);

      // Update meeting with session ID
      final meeting = await widget.serverService.meetings.get(widget.meetingId);
      if (meeting != null) {
        final sessionIds = List<String>.from(meeting.sessionIds);
        if (!sessionIds.contains(sessionId)) {
          sessionIds.add(sessionId);
          meeting.sessionIds = sessionIds;
          await widget.serverService.meetings.put(meeting);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session created successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating session: $e')));
      }
    }
  }

  /// Generate cryptographically secure secret
  String _generateSecret() {
    final secureRandom = Random.secure();
    final bytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Voting Session')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Session Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Session Title',
                border: OutlineInputBorder(),
                hintText: 'Enter session name',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a session title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Voting Type (secret / nonsecret)
            DropdownButtonFormField<VotingType>(
              value: _votingType,
              decoration: const InputDecoration(
                labelText: 'Voting Type',
                border: OutlineInputBorder(),
                helperText:
                    'Secret: anonymous votes | Non-secret: visible votes',
              ),
              items: VotingType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(
                    type == VotingType.secret
                        ? 'Secret (Anonymous)'
                        : 'Non-secret (Public)',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _votingType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Duration
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Voting Duration (minutes)',
                border: OutlineInputBorder(),
                hintText: 'e.g. 15',
                helperText:
                    'How long voting will be open after admin starts it',
                suffixText: 'min',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter duration';
                }
                final minutes = int.tryParse(value.trim());
                if (minutes == null || minutes <= 0) {
                  return 'Please enter a valid number of minutes';
                }
                return null;
              },
              onChanged: (value) {
                final minutes = int.tryParse(value);
                if (minutes != null && minutes > 0) {
                  _durationMinutes = minutes;
                }
              },
            ),
            const SizedBox(height: 24),

            // Questions Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Questions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                  onPressed: _addQuestion,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Help text
            const Text(
              'Each question can have its own type:\n'
              '• Yes/No - Two options\n'
              '• Yes/No/Abstain - Three options\n'
              '• Custom - Define your own options',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Questions List
            ...List.generate(
              _questions.length,
              (index) => _buildQuestionCard(index),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _saving ? null : _createSession,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Create Session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int questionIndex) {
    final question = _questions[questionIndex];
    final isCustom = question.answerSchema == AnswersSchema.custom;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header with delete button
            Row(
              children: [
                Text(
                  'Question ${questionIndex + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeQuestion(questionIndex),
                  tooltip: 'Remove Question',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Question text
            TextFormField(
              controller: question.textController,
              decoration: const InputDecoration(
                labelText: 'Question Text',
                border: OutlineInputBorder(),
                hintText: 'Enter your question',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Question text is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Question Type Selector
            DropdownButtonFormField<AnswersSchema>(
              value: question.answerSchema,
              decoration: const InputDecoration(
                labelText: 'Question Type',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: AnswersSchema.yesNo,
                  child: const Text('Yes / No'),
                ),
                DropdownMenuItem(
                  value: AnswersSchema.yesNoAbstain,
                  child: const Text('Yes / No / Abstain'),
                ),
                DropdownMenuItem(
                  value: AnswersSchema.custom,
                  child: const Text('Custom Options'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _changeQuestionType(questionIndex, value);
                }
              },
            ),

            // Show options section only for custom type
            if (isCustom) ...[
              const SizedBox(height: 16),

              // Max selections for custom
              Row(
                children: [
                  const Text('User can select: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: question.maxSelections,
                    items:
                        List.generate(
                          question.options.isEmpty
                              ? 5
                              : question.options.length,
                          (n) => n + 1,
                        ).map((n) {
                          return DropdownMenuItem(
                            value: n,
                            child: Text('$n option${n > 1 ? 's' : ''}'),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => question.maxSelections = value);
                      }
                    },
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Option'),
                    onPressed: () => _addOption(questionIndex),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Options list
              ...List.generate(question.options.length, (optionIndex) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller:
                              question.options[optionIndex].textController,
                          decoration: InputDecoration(
                            labelText: 'Option ${optionIndex + 1}',
                            border: const OutlineInputBorder(),
                            hintText: 'Enter option text',
                          ),
                          validator: (value) {
                            if (isCustom &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Option text required';
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _removeOption(questionIndex, optionIndex),
                        tooltip: 'Remove Option',
                      ),
                    ],
                  ),
                );
              }),

              if (question.options.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Add at least one option for custom questions',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
            ] else ...[
              // Show preview for non-custom types
              const SizedBox(height: 8),
              Text(
                'Options: ${question.answerSchema == AnswersSchema.yesNo ? "Yes, No" : "Yes, No, Abstain"}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class QuestionData {
  final String id;
  final TextEditingController textController;
  AnswersSchema answerSchema;
  int maxSelections;
  List<OptionData> options;

  QuestionData({
    required this.id,
    required this.textController,
    this.answerSchema = AnswersSchema.yesNoAbstain,
    this.maxSelections = 1,
    List<OptionData>? options,
  }) : options = options ?? [];
}

class OptionData {
  final String id;
  final TextEditingController textController;

  OptionData({required this.id, required this.textController});
}
