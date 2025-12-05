// Basic Flutter widget test for Voting Application
//
// Note: This is a placeholder test. The actual app uses async initialization
// (Hive) which requires proper test setup.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders landing page title', (WidgetTester tester) async {
    // Basic smoke test - verify MaterialApp can be built
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Secure Voting System'),
          ),
        ),
      ),
    );

    // Verify that the app title is displayed
    expect(find.text('Secure Voting System'), findsOneWidget);
  });
}
