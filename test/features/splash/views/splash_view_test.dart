import 'dart:async';

import 'package:faunawatch/features/auth/models/auth_destination.dart';
import 'package:faunawatch/features/auth/services/google_auth_service.dart';
import '../../auth/fake_google_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/splash/views/splash_view.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';

void main() {
  late FakeGoogleAuthService service;

  setUp(() => service = FakeGoogleAuthService());
  tearDown(() => service.dispose());

  Widget createWidgetUnderTest({
    bool autoNavigate = true,
    bool reduceMotion = false,
  }) {
    return ProviderScope(
      overrides: [googleAuthServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: SplashView(autoNavigate: autoNavigate),
      ),
    );
  }

  double nameOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('FaunaWatch'),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  group('SplashView', () {
    testWidgets('starts on the fox alone, then shows the name', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(autoNavigate: false));

      expect(find.byType(Image), findsOneWidget);
      expect(nameOpacity(tester), 0);
      expect(find.text('Splash Screen Placeholder'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(SplashView.introDuration);
      expect(nameOpacity(tester), 1);
    });

    testWidgets('waits for the intro even when sign-in is quick', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(WelcomeView), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeView), findsOneWidget);
      expect(
        find.text('Mapping life, one sighting at a time.'),
        findsOneWidget,
      );
    });

    testWidgets('waits for a slow sign-in and shows a spinner after 3s', (
      tester,
    ) async {
      service.pendingResolution = Completer<AuthDestination>();
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.byType(SplashView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      service.pendingResolution!.complete(AuthDestination.signedOut);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsOneWidget);
    });

    testWidgets('shows the final frame at once when motion is reduced', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest(reduceMotion: true));
      expect(nameOpacity(tester), 1);

      // No intro to wait for: only the 350 ms fade to the next screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(WelcomeView), findsOneWidget);
    });

    testWidgets('shows a white Retry message when restoring fails', (
      tester,
    ) async {
      service.resolveError = StateError('offline');
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(SplashView.introDuration);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      const message = 'Could not restore your session. Please try again.';
      expect(find.text(message), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(message)).style?.color,
        Colors.white,
      );

      service.resolveError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsOneWidget);
    });
  });
}
