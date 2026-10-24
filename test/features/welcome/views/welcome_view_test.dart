import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';
import 'package:faunawatch/features/welcome/views/widgets/welcome_pop_button.dart';

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      child: MaterialApp(theme: AppTheme.lightTheme, home: const WelcomeView()),
    );
  }

  group('WelcomeView', () {
    testWidgets('renders tagline and both action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      expect(
        find.text('Mapping life, one sighting at a time.'),
        findsOneWidget,
      );
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.byType(WelcomePopButton), findsNWidgets(2));
    });

    testWidgets('tapping Log In navigates forward to login destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome\nBack!'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
    });

    testWidgets('tapping Sign Up navigates forward to sign up destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text("Let's Get\nStarted"), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });
  });
}
