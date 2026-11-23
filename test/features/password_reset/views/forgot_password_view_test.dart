import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/password_reset/services/password_reset_service.dart';
import 'package:faunawatch/features/password_reset/views/screens/forgot_password_view.dart';
import '../fake_password_reset_service.dart';

void main() {
  late FakePasswordResetService service;

  Future<void> pumpScreen(WidgetTester tester, {String email = ''}) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    service = FakePasswordResetService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [passwordResetServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ForgotPasswordView(initialEmail: email),
                  ),
                ),
                child: const Text('Log In screen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Log In screen'));
    await tester.pumpAndSettle();
  }

  testWidgets('send, wait a minute, send again', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Forgot\nPassword?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'spotter@example.com');
    await tester.pump();
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();

    expect(service.sentTo, ['spotter@example.com']);
    expect(find.text('Check your\nemail'), findsOneWidget);
    expect(
      find.textContaining('If an account uses spotter@example.com'),
      findsOneWidget,
    );
    expect(find.textContaining('Open the link on this phone'), findsWidgets);
    expect(find.text('Send Again in 60s'), findsOneWidget);

    await tester.tap(find.text('Send Again in 60s'));
    await tester.pump();
    expect(service.sentTo, hasLength(1));

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Send Again in 1s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Send Again'), findsOneWidget);

    await tester.tap(find.text('Send Again'));
    await tester.pump();
    expect(service.sentTo, ['spotter@example.com', 'spotter@example.com']);

    // Stop the new countdown before the test ends.
    await tester.tap(find.text('Use a different email'));
    await tester.pumpAndSettle();
    expect(find.text('Send Reset Link'), findsOneWidget);
  });

  testWidgets('the email typed on Log In is filled in', (tester) async {
    await pumpScreen(tester, email: ' spotter@example.com ');
    await tester.pump();
    expect(find.text('spotter@example.com'), findsOneWidget);

    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    expect(service.sentTo, ['spotter@example.com']);

    await tester.tap(find.text('Back to Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Log In screen'), findsOneWidget);
  });

  testWidgets('an error stays on the form', (tester) async {
    await pumpScreen(tester, email: 'spotter@example.com');
    await tester.pump();
    service.sendError = StateError('down');

    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();

    expect(
      find.text("We couldn't send the reset link. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Send Reset Link'), findsOneWidget);
  });
}
