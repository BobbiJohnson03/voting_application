import 'package:flutter/material.dart';
import '../models/voting.dart';
import '../models/meeting.dart';
import '../models/question.dart';

/// PrintService - temporarily disabled due to Android SDK compatibility issues
/// The 'printing' package requires Android SDK attributes not available in current config.
/// To re-enable: add 'printing: ^5.12.0' to pubspec.yaml and restore original code.
///
/// Alternative: Use ExportService.exportToPDF() which saves PDF to file instead of printing.
class PrintService {
  /// Print voting results - DISABLED
  Future<void> printResults(
    Voting voting,
    Map<String, Map<String, int>> results,
    Meeting meeting,
    List<Question> questions,
  ) async {
    debugPrint('Print functionality is temporarily disabled');
    throw UnimplementedError(
      'Print functionality is temporarily disabled due to Android SDK compatibility. '
      'Use PDF export instead.',
    );
  }

  /// Print meeting summary - DISABLED
  Future<void> printMeetingSummary(
    Meeting meeting,
    List<Voting> votings,
    Map<String, Map<String, Map<String, int>>> allResults,
  ) async {
    debugPrint('Print functionality is temporarily disabled');
    throw UnimplementedError(
      'Print functionality is temporarily disabled due to Android SDK compatibility. '
      'Use PDF export instead.',
    );
  }
}
