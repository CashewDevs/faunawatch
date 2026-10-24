import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/auth/views/sign_up_view.dart';
import 'package:faunawatch/features/auth/views/widgets/login_action_button.dart';

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      child: MaterialApp(theme: AppTheme.lightTheme, home: const SignUpView()),
    );
  }

  group('SignUpView', () {
    testWidgets('renders header, inputs, buttons, and social options', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text("Let's Get\nStarted"), findsOneWidget);
      expect(find.text('Make every\nencounter count.'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(LoginActionButton, 'Sign Up'), findsOneWidget);
      expect(find.text('or continue with'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.textContaining('Already have an account?'), findsOneWidget);
      expect(find.textContaining('Log In'), findsOneWidget);
    });

    testWidgets(
      'Sign Up button is disabled initially and activates when all credentials are typed',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        final buttonFinder = find.byType(LoginActionButton);
        expect(buttonFinder, findsOneWidget);

        var buttonWidget = tester.widget<LoginActionButton>(buttonFinder);
        expect(buttonWidget.isEnabled, false);

        final textFields = find.byType(TextField);
        expect(textFields, findsNWidgets(3));

        // Enter email
        await tester.enterText(textFields.at(0), 'scout@fauna.org');
        await tester.pump();
        buttonWidget = tester.widget<LoginActionButton>(buttonFinder);
        expect(buttonWidget.isEnabled, false);

        // Enter password
        await tester.enterText(textFields.at(1), 'mypassword123');
        await tester.pump();
        buttonWidget = tester.widget<LoginActionButton>(buttonFinder);
        expect(buttonWidget.isEnabled, false);

        // Enter confirm password
        await tester.enterText(textFields.at(2), 'mypassword123');
        await tester.pump();
        buttonWidget = tester.widget<LoginActionButton>(buttonFinder);
        expect(buttonWidget.isEnabled, true);
      },
    );

    testWidgets(
      'tapping active Sign Up button completes and navigates to ProfileSetupView',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'scout@fauna.org');
        await tester.enterText(textFields.at(1), 'mypassword123');
        await tester.enterText(textFields.at(2), 'mypassword123');
        await tester.pump();

        await tester.tap(find.widgetWithText(LoginActionButton, 'Sign Up'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('What should we\ncall you?'), findsOneWidget);
        expect(find.text('Add a Bio!'), findsOneWidget);
      },
    );

    testWidgets('tapping Log In footer navigates to LoginView', (tester) async {
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
      expect(find.text("Don't have an account yet? "), findsOneWidget);
    });
  });
}
