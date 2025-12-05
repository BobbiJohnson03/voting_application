import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/voting.dart';
import '../models/question.dart';
import '../models/meeting.dart';

class ExportService {
  /// Export voting results to CSV format
  Future<void> exportToCSV(
    Voting session,
    Map<String, Map<String, int>> results,
    Meeting meeting, {
    List<Question>? questions,
  }) async {
    try {
      // Create CSV data
      List<List<dynamic>> csvData = [];

      // Header
      csvData.add([
        'Voting ID',
        'Voting Title',
        'Meeting Name',
        'Voting Type',
        'Total Votes',
        'Export Date',
      ]);

      // Voting info
      csvData.add([
        session.id,
        session.title,
        meeting.title,
        session.type.name,
        results.values.fold(
          0,
          (sum, q) => sum + q.values.fold(0, (sum2, v) => sum2 + v),
        ),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      ]);

      csvData.add([]); // Empty row

      // Questions header
      csvData.add([
        'Question ID',
        'Question Text',
        'Option ID',
        'Option Text',
        'Votes',
        'Percentage',
      ]);

      // Build question lookup map if questions provided
      final questionMap = <String, Question>{};
      if (questions != null) {
        for (final q in questions) {
          questionMap[q.id] = q;
        }
      }

      // Results data
      for (final entry in results.entries) {
        final questionId = entry.key;
        final questionResults = entry.value;
        final question = questionMap[questionId];

        for (final optionResult in questionResults.entries) {
          final optionId = optionResult.key;
          final votes = optionResult.value;

          // Get question and option text from Question model if available
          final questionText = question?.text ?? 'Question $questionId';
          final option = question?.options
              .where((o) => o.id == optionId)
              .firstOrNull;
          final optionText = option?.text ?? 'Option $optionId';

          // Calculate percentage
          final totalVotes = questionResults.values.fold(
            0,
            (sum, v) => sum + v,
          );
          final percentage = totalVotes > 0
              ? (votes / totalVotes * 100).toStringAsFixed(2)
              : '0.00';

          csvData.add([
            questionId,
            questionText,
            optionId,
            optionText,
            votes,
            '$percentage%',
          ]);
        }
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      // Create file
      final fileName =
          'voting_results_${session.id}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = await _createTempFile(fileName, csv);

      // Share file
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Voting Results - ${session.title}');

      // Clean up
      await file.delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error exporting to CSV: $e');
      }
      rethrow;
    }
  }

  /// Export voting results to PDF format
  Future<void> exportToPDF(
    Voting session,
    Map<String, Map<String, int>> results,
    Meeting meeting,
    List<Question> questions,
  ) async {
    try {
      final pdf = pw.Document();

      // Add page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Header(level: 0, child: pw.Text('Voting Results Report')),

                // Meeting and Voting Info
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Meeting: ${meeting.title}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Voting: ${session.title}'),
                      pw.SizedBox(height: 4),
                      pw.Text('Type: ${session.type.name}'),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Export Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                      ),
                    ],
                  ),
                ),

                // Results
                pw.SizedBox(height: 30),
                pw.Header(level: 1, child: pw.Text('Voting Results')),

                // Questions and Results
                ...questions.map((question) {
                  final questionResults = results[question.id] ?? {};
                  final totalVotes = questionResults.values.fold(
                    0,
                    (sum, v) => sum + v,
                  );

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          question.text,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        ...question.options.map((option) {
                          final votes = questionResults[option.id] ?? 0;
                          final percentage = totalVotes > 0
                              ? (votes / totalVotes * 100)
                              : 0.0;

                          return pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 3,
                                  child: pw.Text(option.text),
                                ),
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Text('$votes votes'),
                                ),
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        pw.SizedBox(height: 12),
                        // Progress bar visualization
                        pw.Container(
                          height: 20,
                          child: pw.Row(
                            children: question.options.map((option) {
                              final votes = questionResults[option.id] ?? 0;
                              final percentage = totalVotes > 0
                                  ? (votes / totalVotes)
                                  : 0.0;

                              return pw.Container(
                                width: percentage * 300, // 300 is total width
                                height: 20,
                                color: _getChartColor(
                                  question.options.indexOf(option),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Footer
                pw.SizedBox(height: 30),
                pw.Container(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Generated by Voting App',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final fileName =
          'voting_results_${session.id}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final bytes = await pdf.save();
      final file = await _createTempFile(fileName, bytes);

      // Share file
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Voting Results PDF - ${session.title}');

      // Clean up
      await file.delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error exporting to PDF: $e');
      }
      rethrow;
    }
  }

  /// Export meeting summary to PDF
  Future<void> exportMeetingSummary(
    Meeting meeting,
    List<Voting> sessions,
    Map<String, Map<String, Map<String, int>>> allResults,
  ) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Header(level: 0, child: pw.Text('Meeting Summary Report')),

                // Meeting Info
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Meeting: ${meeting.title}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Join Code: ${meeting.joinCode}'),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(meeting.createdAt)}',
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Total Votings: ${sessions.length}'),
                    ],
                  ),
                ),

                // Votings Summary
                pw.SizedBox(height: 30),
                pw.Header(level: 1, child: pw.Text('Votings Summary')),

                pw.Table.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    ['Voting Title', 'Type', 'Status', 'Total Votes'],
                    ...sessions.map((session) {
                      final sessionResults = allResults[session.id] ?? {};
                      final totalVotes = sessionResults.values
                          .map((q) => q.values.fold(0, (sum, v) => sum + v))
                          .fold(0, (sum, v) => sum + v);

                      return [
                        session.title,
                        session.type.name,
                        session.status.name,
                        totalVotes.toString(),
                      ];
                    }).toList(),
                  ],
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                  },
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final fileName =
          'meeting_summary_${meeting.id}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final bytes = await pdf.save();
      final file = await _createTempFile(fileName, bytes);

      // Share file
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Meeting Summary - ${meeting.title}');

      // Clean up
      await file.delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error exporting meeting summary: $e');
      }
      rethrow;
    }
  }

  /// Create temporary file
  Future<File> _createTempFile(String fileName, dynamic content) async {
    final directory = Directory.systemTemp;
    final file = File('${directory.path}/$fileName');

    if (content is String) {
      await file.writeAsString(content);
    } else if (content is Uint8List) {
      await file.writeAsBytes(content);
    }

    return file;
  }

  /// Get chart color for visualization
  PdfColor _getChartColor(int index) {
    final colors = [
      PdfColors.blue,
      PdfColors.green,
      PdfColors.orange,
      PdfColors.red,
      PdfColors.purple,
      PdfColors.teal,
      PdfColors.indigo,
      PdfColors.pink,
    ];
    return colors[index % colors.length];
  }
}
