import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
import 'package:faunawatch/features/onboarding/views/onboarding_view.dart';
import 'package:faunawatch/features/onboarding/views/widgets/begin_watch_button.dart';
import 'package:faunawatch/features/onboarding/views/widgets/onboarding_indicator.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';
import '../../profile/fake_profile_service.dart';

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
        profileServiceProvider.overrideWithValue(FakeProfileService()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OnboardingView(),
      ),
    );
  }

  group('OnboardingView', () {
    testWidgets('renders first slide headers, indicator, and forward button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Spot & Identify'), findsOneWidget);
      expect(find.text('Artwork Placeholder'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == AppAssets.onboardingBg1,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Scan encounters through your camera to\nidentify species and risk levels.',
        ),
        findsOneWidget,
      );
      expect(find.byType(OnboardingIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Next'), findsOneWidget);
      expect(find.byType(BeginWatchButton), findsNothing);
    });

    testWidgets(
      'tapping forward button advances through slides to Begin the Watch',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        // 1st -> 2nd
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Real-Time Alerts'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == AppAssets.onboardingBg2,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Track live encounters and stay\nupdated on sightings near you.',
          ),
          findsOneWidget,
        );

        // 2nd -> 3rd
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Protect & Report'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == AppAssets.onboardingBg3,
          ),
          findsOneWidget,
        );
        expect(
          find.text('Report animals in need and keep\nyour neighborhood safe.'),
          findsOneWidget,
        );
        expect(find.byType(BeginWatchButton), findsOneWidget);
      },
    );

    testWidgets('tapping Begin the Watch completes walkthrough to ShellView', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Advance to 2nd slide
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Advance to 3rd slide
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Tap Begin the Watch button
      await tester.tap(find.bySemanticsLabel('Begin the Watch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(ShellView), findsOneWidget);
    });
  });
}
