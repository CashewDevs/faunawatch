import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/intro/views/intro_view.dart';
import 'package:faunawatch/features/terms/views/terms_consent_view.dart';

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TermsConsentView(),
                  ),
                ),
                child: const Text('Open terms'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openTerms(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.text('Open terms'));
    await tester.pumpAndSettle();
  }

  Finder continueButton() => find.text('I agree, continue  >');

  Future<void> tapCheckbox(WidgetTester tester, Finder label) async {
    await tester.scrollUntilVisible(
      label,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(label);
    await tester.pump();
  }

  group('TermsConsentView', () {
    testWidgets('expands one section at a time', (tester) async {
      await openTerms(tester);

      const neighbourDetails =
          'Only share photos you took yourself. No harassment, spam or '
          'misleading reports. We may remove posts that break these rules.';
      expect(find.text(neighbourDetails), findsNothing);

      await tester.tap(find.text('Be a good neighbour'));
      await tester.pumpAndSettle();
      expect(find.text(neighbourDetails), findsOneWidget);

      await tester.tap(find.text('Stay safe out there'));
      await tester.pumpAndSettle();
      expect(find.text(neighbourDetails), findsNothing);
      expect(find.textContaining('Keep a safe distance'), findsOneWidget);
    });

    testWidgets('continue stays disabled until both boxes are ticked', (
      tester,
    ) async {
      await openTerms(tester);

      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.byType(IntroView), findsNothing);

      await tapCheckbox(
        tester,
        find.text('I agree to the Terms of Service and Privacy Policy.'),
      );
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.byType(IntroView), findsNothing);

      await tapCheckbox(
        tester,
        find.textContaining('I understand AI results are preliminary'),
      );
      await tester.tap(continueButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(IntroView), findsOneWidget);
    });

    testWidgets('decline asks for confirmation before going back', (
      tester,
    ) async {
      await openTerms(tester);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Agreement needed'), findsOneWidget);

      await tester.tap(find.text('Review terms'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsConsentView), findsOneWidget);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsConsentView), findsNothing);
      expect(find.text('Open terms'), findsOneWidget);
    });
  });
}
