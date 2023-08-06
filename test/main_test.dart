import 'package:flutter_test/flutter_test.dart';
import 'package:libu/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Testing Add Item Dialog', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap on the FloatingActionButton to show the Add Item dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Check if the Add Item dialog is displayed
    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Testing Tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Check if both tabs are available
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Tap on History Tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // Check if History tab is displayed
    // Since there's no history data initially, just check if the CircularProgressIndicator is displayed
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}