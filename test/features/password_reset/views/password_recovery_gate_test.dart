import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/password_reset/services/password_reset_service.dart';
import 'package:faunawatch/features/password_reset/views/password_recovery_gate.dart';
import '../fake_password_reset_service.dart';

void main() {
  late FakePasswordResetService service;
  late FakeAuthService auth;

  /// Like the app: the gate wraps the navigator, which starts at "Home".
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    service = FakePasswordResetService();
    auth = FakeAuthService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          passwordResetServiceProvider.overrideWithValue(service),
          authServiceProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => PasswordRecoveryGate(child: child),
          home: const Scaffold(body: Text('Home screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLink(WidgetTester tester, ResetLinkEvent event) async {
    service.links.add(event);
    await tester.pumpAndSettle();
  }

  testWidgets('no link: the app as usual', (tester) async {
    await pumpApp(tester);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('choose a new password, then back to the app', (tester) async {
    await pumpApp(tester);
    await openLink(tester, ResetLinkEvent.opened);

    expect(find.text('Home screen'), findsNothing);
    expect(find.text('Choose a new\npassword'), findsOneWidget);
    expect(find.textContaining('spotter@example.com'), findsOneWidget);
    expect(
      find.bySemanticsLabel('At least 8 characters: not met'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), 'newpass123');
    await tester.enterText(find.byType(TextField).at(1), 'newpass123');
    await tester.pump();
    expect(find.bySemanticsLabel('At least 8 characters: met'), findsOneWidget);
    expect(find.bySemanticsLabel('Both passwords match: met'), findsOneWidget);

    await tester.tap(find.text('Save Password'));
    await tester.pumpAndSettle();

    expect(service.savedPasswords, ['newpass123']);
    expect(find.text('Password\nupdated'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
    expect(auth.signOuts, 0);
  });

  testWidgets('the eye button shows the password', (tester) async {
    await pumpApp(tester);
    await openLink(tester, ResetLinkEvent.opened);

    TextField field() => tester.widget<TextField>(find.byType(TextField).first);
    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('a refused password shows why and stays', (tester) async {
    await pumpApp(tester);
    await openLink(tester, ResetLinkEvent.opened);
    service.saveError = StateError('down');

    await tester.enterText(find.byType(TextField).at(0), 'newpass123');
    await tester.enterText(find.byType(TextField).at(1), 'newpass123');
    await tester.pump();
    await tester.tap(find.text('Save Password'));
    await tester.pumpAndSettle();

    expect(
      find.text("We couldn't save your new password. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Choose a new\npassword'), findsOneWidget);
  });

  testWidgets('cancel logs out and returns to the app', (tester) async {
    await pumpApp(tester);
    await openLink(tester, ResetLinkEvent.opened);

    await tester.tap(find.text('Cancel and log out'));
    await tester.pumpAndSettle();

    expect(auth.signOuts, 1);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('a link that cannot be used explains why', (tester) async {
    await pumpApp(tester);
    await openLink(tester, ResetLinkEvent.failed);

    expect(find.text("This link can't\nbe used"), findsOneWidget);
    expect(find.textContaining('only works on the phone'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
  });
}
