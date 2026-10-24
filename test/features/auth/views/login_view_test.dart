import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/auth/views/login_view.dart';
import 'package:faunawatch/features/auth/views/widgets/auth_text_field.dart';
import 'package:faunawatch/features/auth/views/widgets/login_action_button.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> signUp(String email, String password) async => true;

  @override
  Future<void> signOut() async {}
}

class _FakeProfileService implements ProfileService {
  @override
  Future<bool> saveProfile({
    required String username,
    required String bio,
  }) async => true;

  @override
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  }) async => true;

  @override
  Future<bool> saveProfileBanner({
    String? bannerAsset,
    int? colorValue,
  }) async => true;
}

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        currentUserIdProvider.overrideWith((ref) => Stream.value('user-123')),
        profileServiceProvider.overrideWithValue(_FakeProfileService()),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const LoginView()),
    );
  }

  group('LoginView', () {
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

      expect(find.text('Welcome\nBack!'), findsOneWidget);
      expect(find.text('Ready to resume\nthe watch?'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('or continue with'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.textContaining("Don't have an account yet?"), findsOneWidget);
      expect(find.textContaining('Sign Up'), findsOneWidget);
    });

    testWidgets(
      'Log In button is disabled initially and activates when credentials are typed',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        // Find the LoginActionButton
        final buttonFinder = find.byType(LoginActionButton);
        expect(buttonFinder, findsOneWidget);

        var buttonWidget = tester.widget<LoginActionButton>(buttonFinder);
        expect(buttonWidget.isEnabled, false);

        // Enter email only
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ranger@fauna.org');
        await tester.pump();

        buttonWidget = tester.widget<LoginActionButton>(buttonFinder);
        expect(buttonWidget.isEnabled, false);

        // Enter password
        await tester.enterText(textFields.last, 'safepass123');
        await tester.pump();

        buttonWidget = tester.widget<LoginActionButton>(buttonFinder);
        expect(buttonWidget.isEnabled, true);
      },
    );

    testWidgets('tapping password visibility icon toggles obscureText', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      final passwordFieldFinder = find.widgetWithText(
        AuthTextField,
        'Password',
      );
      expect(passwordFieldFinder, findsOneWidget);

      var textFieldWidget = tester.widget<TextField>(
        find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(TextField),
        ),
      );
      expect(textFieldWidget.obscureText, true);

      // Tap suffix visibility button
      final toggleButton = find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(IconButton),
      );
      await tester.tap(toggleButton);
      await tester.pump();

      textFieldWidget = tester.widget<TextField>(
        find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(TextField),
        ),
      );
      expect(textFieldWidget.obscureText, false);
    });

    testWidgets(
      'tapping active Log In button completes and navigates to ShellView',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ranger@fauna.org');
        await tester.enterText(textFields.last, 'safepass123');
        await tester.pump();

        await tester.tap(find.text('Log In'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(ShellView), findsOneWidget);
        expect(find.text('No posts yet.'), findsOneWidget);
      },
    );

    testWidgets('tapping Sign Up footer navigates to SignUpView', (
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
