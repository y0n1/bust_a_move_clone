import 'package:bust_a_move_clone/start_screen/start_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartScreen', () {
    testWidgets('displays title text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StartScreen()),
      );
      expect(find.text('BUST A MOVE'), findsOneWidget);
    });

    testWidgets('displays PLAY button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StartScreen()),
      );
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('displays instructions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StartScreen()),
      );
      expect(
        find.text('Aim with the mouse or finger, tap to fire.\nMatch 3+ of a color to pop. Clear the board!'),
        findsOneWidget,
      );
    });
  });
}
