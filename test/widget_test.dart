// This is a Flutter widget test for the LinkNest app.
//
// To perform an interaction with a widget, use the WidgetTester utility
// in the flutter_test package. For example, you can send tap and scroll
// gestures, find child widgets, read text, and verify widget properties.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:link_saver/main.dart';
import 'package:link_saver/screens/links_page.dart';
void main() {
  setUp(() async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({'isDarkMode': false});
  });

  testWidgets('LinkNest app loads with bottom navigation bar', (WidgetTester tester) async {
    // Build the app and trigger a frame
    await tester.pumpWidget(const LinkNestApp());

    // Allow async operations (e.g., SharedPreferences) to complete
    await tester.pumpAndSettle();

    // Verify the app title in the MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('LinkNest'), findsNothing); // Title is not directly visible in UI

    // Verify the MainScreen is displayed
    expect(find.byType(MainScreen), findsOneWidget);

    // Verify the bottom navigation bar items
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Links'), findsOneWidget);
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);

    // Verify the FloatingActionButton with '+' icon
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Tap the 'Links' navigation item and verify page change
    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();

    // Verify that the LinksPage is displayed (assuming it has a unique widget, e.g., a title)
    // Note: Adjust this based on actual LinksPage content
    expect(find.byType(LinksPage), findsOneWidget);
  });
}