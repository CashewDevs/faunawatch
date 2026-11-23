import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';
import 'package:faunawatch/features/account_deletion/services/account_deletion_service.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/profile/views/widgets/delete_account_dialog.dart';
import 'package:faunawatch/features/push/services/device_token_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';
import '../../account_deletion/fake_account_deletion_service.dart';
import '../../fauna_lens/ai_fakes.dart';
import '../../push/fake_push_services.dart';
import '../../suspension/fake_suspension_service.dart' show FakeAuthService;

void main() {
  late FakeAccountDeletionService service;

  const field = ValueKey('delete_account_confirm_field');
  const button = ValueKey('delete_account_confirm_button');

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    service = FakeAccountDeletionService();
    final users = StreamController<String?>.broadcast();
    addTearDown(users.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDeletionServiceProvider.overrideWithValue(service),
          authServiceProvider.overrideWithValue(FakeAuthService()),
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
          aiApiKeyStorageServiceProvider.overrideWithValue(FakeKeyStorage()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const DeleteAccountDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  bool buttonEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byKey(button)).onPressed != null;

  testWidgets('explains the 7 days and asks to type Delete', (tester) async {
    await openDialog(tester);

    for (final line in DeleteAccountDialog.consequences) {
      expect(find.text(line), findsOneWidget);
    }
    expect(find.text('Type Delete to confirm'), findsOneWidget);
    expect(buttonEnabled(tester), isFalse);
  });

  testWidgets('the button works only once Delete is typed', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byKey(field), 'Delet');
    await tester.pump();
    expect(buttonEnabled(tester), isFalse);

    await tester.enterText(find.byKey(field), 'delete');
    await tester.pump();
    expect(buttonEnabled(tester), isTrue);
  });

  testWidgets('deleting goes to Welcome and shows the date', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byKey(field), 'Delete');
    await tester.pump();
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();

    expect(service.requests, ['Delete']);
    expect(service.signOutCalls, 1);
    expect(find.byType(DeleteAccountDialog), findsNothing);
    expect(find.byType(WelcomeView), findsOneWidget);
    expect(
      find.text(
        'Your account will be deleted on 1 Dec 2026, 3:40 PM. '
        'Sign in before then to keep it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a refusal is shown and the dialog stays', (tester) async {
    await openDialog(tester);
    service.requestFailure = AccountDeletionFailure.adminAccount;

    await tester.enterText(find.byKey(field), 'Delete');
    await tester.pump();
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountDialog), findsOneWidget);
    expect(
      find.text("Admin accounts can't be deleted from the app."),
      findsOneWidget,
    );
    expect(service.signOutCalls, 0);
  });

  testWidgets('Cancel closes it without deleting', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountDialog), findsNothing);
    expect(service.requests, isEmpty);
  });
}
