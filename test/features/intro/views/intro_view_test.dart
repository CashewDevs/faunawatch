import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/intro/views/intro_view.dart';
import 'package:faunawatch/features/intro/views/widgets/image_drop_shadow.dart';
import 'package:faunawatch/features/intro/views/widgets/swipe_up_indicator.dart';
import 'package:faunawatch/features/onboarding/views/onboarding_view.dart';

void main() {
  Widget createWidgetUnderTest({bool animateArrow = false}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: IntroView(animateArrow: animateArrow),
      ),
    );
  }

  group('IntroView', () {
    testWidgets('renders all brand identity components and drop shadows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(animateArrow: false));
      await tester.pump();

      // Brand headers & tagline
      expect(find.text('Welcome to'), findsOneWidget);
      expect(
        find.text('Mapping life, one sighting at a time.'),
        findsOneWidget,
      );

      // Logo and Wordmark with ImageDropShadow
      expect(find.byType(ImageDropShadow), findsNWidgets(2));

      // Swipe up area components
      expect(find.byType(SwipeUpIndicator), findsOneWidget);
      expect(find.text('Slide Up'), findsOneWidget);
      expect(find.bySemanticsLabel('Slide Up'), findsOneWidget);
    });

    testWidgets(
      'tapping Slide Up button triggers navigation to OnboardingView',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest(animateArrow: false));
        await tester.pump();

        // Tap slide up button
        await tester.tap(find.bySemanticsLabel('Slide Up'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingView), findsOneWidget);
      },
    );

    testWidgets('swiping up triggers navigation to OnboardingView', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(animateArrow: false));
      await tester.pump();

      // Perform swipe up gesture
      await tester.fling(find.byType(IntroView), const Offset(0, -600), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingView), findsOneWidget);
    });
  });
}
