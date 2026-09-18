import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

void main() {
  Widget buildTestShell() {
    return const ProviderScope(
      child: MaterialApp(
        home: ShellView(),
      ),
    );
  }

  group('ShellView', () {
    testWidgets('renders header with FaunaWatch title', (tester) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.text('FaunaWatch'), findsOneWidget);
    });

    testWidgets('renders all four navigation destinations', (tester) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('displays Report placeholder by default', (tester) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.text('Report View'), findsOneWidget);
    });

    testWidgets('switches views when navigation items are tapped',
        (tester) async {
      await tester.pumpWidget(buildTestShell());

      // Tap Map destination
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(find.text('Map View'), findsOneWidget);

      // Tap Alerts destination
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();

      expect(find.text('Alerts View'), findsOneWidget);

      // Tap Profile destination
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Profile View'), findsOneWidget);

      // Tap back to Report destination
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.text('Report View'), findsOneWidget);
    });
  });
}
