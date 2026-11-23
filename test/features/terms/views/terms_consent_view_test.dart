import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
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

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.text('Next  ›'));
    await tester.pumpAndSettle();
  }

  group('TermsConsentView', () {
    testWidgets(
      'steps through all 4 rule screens and supports back navigation',
      (tester) async {
        await openTerms(tester);

        // Step 1 of 4
        expect(find.text('1 of 4'), findsOneWidget);
        expect(find.text('Be a good neighbour'), findsOneWidget);
        expect(find.text('Post real sightings and be kind.'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.byTooltip('Previous rule'), findsNothing);

        // Step 2 of 4
        await tapNext(tester);
        expect(find.text('2 of 4'), findsOneWidget);
        expect(find.text('AI is a helper, not an expert'), findsOneWidget);
        expect(find.byTooltip('Previous rule'), findsOneWidget);

        // Step 3 of 4
        await tapNext(tester);
        expect(find.text('3 of 4'), findsOneWidget);
        expect(find.text('Your photos & location'), findsOneWidget);

        // Back to 2 of 4
        await tester.tap(find.byTooltip('Previous rule'));
        await tester.pumpAndSettle();
        expect(find.text('2 of 4'), findsOneWidget);

        // Forward to 3 -> 4 -> Almost there
        await tapNext(tester);
        await tapNext(tester);
        expect(find.text('4 of 4'), findsOneWidget);
        expect(find.text('Stay safe out there'), findsOneWidget);

        await tapNext(tester);
        expect(find.text('Almost there'), findsOneWidget);
        expect(find.text('One last step before you explore.'), findsOneWidget);
        expect(find.text('v1.0'), findsOneWidget);
        expect(find.textContaining('Last updated'), findsNothing);
        expect(find.text('Skip'), findsNothing);
      },
    );

    testWidgets(
      'Skip opens Almost there with splash_fox, custom gradient, and requires both boxes',
      (tester) async {
        await openTerms(tester);

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(find.text('Almost there'), findsOneWidget);

        // Blue circle contains splash_fox.png.
        final foxBadge = find.byKey(const ValueKey('almost_there_fox_badge'));
        expect(foxBadge, findsOneWidget);
        expect(
          find.descendant(
            of: foxBadge,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.image is AssetImage &&
                  (w.image as AssetImage).assetName == AppAssets.splashFox,
            ),
          ),
          findsOneWidget,
        );

        BoxDecoration continueDecoration() {
          final container = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(PillButton),
                  matching: find.byType(Container),
                )
                .first,
          );
          return container.decoration! as BoxDecoration;
        }

        final gradient = continueDecoration().gradient! as LinearGradient;
        expect(gradient.begin, Alignment.centerLeft);
        expect(gradient.end, Alignment.centerRight);
        expect(gradient.colors, const [Color(0xFFD3E6B6), Color(0xFFB2EFFF)]);

        expect(
          (continueDecoration().border! as Border).top.color,
          AppColors.consentButtonBorder,
        );

        await tester.tap(continueButton());
        await tester.pumpAndSettle();
        expect(find.byType(IntroView), findsNothing);

        await tester.tap(
          find.text('I agree to the Terms of Service and Privacy Policy.'),
        );
        await tester.pump();
        expect(
          (continueDecoration().border! as Border).top.color,
          AppColors.consentButtonBorder,
        );
        await tester.tap(continueButton());
        await tester.pumpAndSettle();
        expect(find.byType(IntroView), findsNothing);

        await tester.tap(
          find.textContaining('I understand AI results are preliminary'),
        );
        await tester.pump();
        expect(
          (continueDecoration().border! as Border).top.color,
          AppColors.loginButtonStroke,
        );

        await tester.tap(continueButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(IntroView), findsOneWidget);
      },
    );

    testWidgets('decline asks for confirmation before going back', (
      tester,
    ) async {
      await openTerms(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

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
