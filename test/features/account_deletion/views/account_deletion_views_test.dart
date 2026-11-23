import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';
import 'package:faunawatch/features/account_deletion/services/account_deletion_service.dart';
import 'package:faunawatch/features/account_deletion/viewmodels/account_deletion_viewmodel.dart';
import 'package:faunawatch/features/account_deletion/views/account_deletion_gate.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/push/services/device_token_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';
import '../../push/fake_push_services.dart';
import '../../suspension/fake_suspension_service.dart' show FakeAuthService;
import '../fake_account_deletion_service.dart';

void main() {
  late FakeAccountDeletionService service;
  late FakeAuthService auth;
  final waiting = AccountDeletion(deleteAfter: fakeDeleteAfter);

  Future<void> pumpApp(
    WidgetTester tester,
    AccountDeletion? scheduled, {
    DateTime? now,
  }) async {
    service = FakeAccountDeletionService(scheduled: scheduled);
    auth = FakeAuthService();
    final users = StreamController<String?>.broadcast();
    addTearDown(users.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDeletionServiceProvider.overrideWithValue(service),
          accountDeletionClockProvider.overrideWithValue(
            () => now ?? DateTime(2026, 11, 24, 9),
          ),
          authServiceProvider.overrideWithValue(auth),
          pushMessagingServiceProvider.overrideWithValue(
            FakePushMessagingService(),
          ),
          deviceTokenServiceProvider.overrideWithValue(
            FakeDeviceTokenService(),
          ),
          pushPreferencesServiceProvider.overrideWithValue(
            FakePushPreferencesService(),
          ),
          currentUserIdProvider.overrideWith((ref) => users.stream),
        ],
        child: MaterialApp(
          builder: (context, child) => AccountDeletionGate(child: child),
          home: const Scaffold(body: Text('Home screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('not waiting: the app as usual', (tester) async {
    await pumpApp(tester, null);

    expect(find.text('Home screen'), findsOneWidget);
    expect(find.text('Your account will be deleted'), findsNothing);
  });

  testWidgets('waiting: only the deletion screen, with the date', (
    tester,
  ) async {
    await pumpApp(tester, waiting);

    expect(find.text('Home screen'), findsNothing);
    expect(find.text('Your account will be deleted'), findsOneWidget);
    expect(
      find.textContaining('It will be deleted on 1 Dec 2026, 3:40 PM.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('scheduled_deletion_keep')), findsOneWidget);
    expect(
      find.byKey(const Key('scheduled_deletion_sign_out')),
      findsOneWidget,
    );
  });

  testWidgets('Keep my account brings the app back and says so', (
    tester,
  ) async {
    await pumpApp(tester, waiting);

    await tester.tap(find.byKey(const Key('scheduled_deletion_keep')));
    await tester.pumpAndSettle();

    expect(service.cancelCalls, 1);
    expect(find.text('Home screen'), findsOneWidget);
    expect(find.text('Welcome back! Your account is restored.'), findsOne);
  });

  testWidgets('past the date: being deleted, Sign out only', (tester) async {
    await pumpApp(tester, waiting, now: fakeDeleteAfter);

    expect(find.text('Your account is being deleted'), findsOneWidget);
    expect(find.byKey(const Key('scheduled_deletion_keep')), findsNothing);
    expect(
      find.byKey(const Key('scheduled_deletion_sign_out')),
      findsOneWidget,
    );
  });

  testWidgets('too late on the server: says so and hides Keep', (tester) async {
    await pumpApp(tester, waiting);
    service.cancelFailure = AccountDeletionFailure.tooLate;

    await tester.tap(find.byKey(const Key('scheduled_deletion_keep')));
    await tester.pumpAndSettle();

    expect(find.text(AccountDeletionFailure.tooLate.message), findsOneWidget);
    expect(find.text('Your account is being deleted'), findsOneWidget);
    expect(find.byKey(const Key('scheduled_deletion_keep')), findsNothing);
  });

  testWidgets('Sign out signs out', (tester) async {
    await pumpApp(tester, waiting);

    await tester.tap(find.byKey(const Key('scheduled_deletion_sign_out')));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
  });
}
