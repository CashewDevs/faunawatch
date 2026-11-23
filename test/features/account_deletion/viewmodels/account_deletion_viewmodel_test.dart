import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';
import 'package:faunawatch/features/account_deletion/services/account_deletion_service.dart';
import 'package:faunawatch/features/account_deletion/viewmodels/account_deletion_viewmodel.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/push/services/device_token_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import '../../fauna_lens/ai_fakes.dart';
import '../../push/fake_push_services.dart';
import '../../suspension/fake_suspension_service.dart' show FakeAuthService;
import '../fake_account_deletion_service.dart';

void main() {
  late FakeAccountDeletionService service;
  late FakeDeviceTokenService tokens;
  late FakeKeyStorage keys;
  late FakeAuthService auth;
  late ProviderContainer container;
  // The push tokens already removed when the sessions were ended.
  List<String>? unregisteredAtSignOut;

  Future<void> start({
    AccountDeletion? scheduled,
    bool signOutFails = false,
    DateTime Function()? clock,
  }) async {
    service = FakeAccountDeletionService(
      scheduled: scheduled,
      signOutFails: signOutFails,
      onSignOutEverywhere: () =>
          unregisteredAtSignOut = List.of(tokens.unregistered),
    );
    tokens = FakeDeviceTokenService();
    keys = FakeKeyStorage()
      ..keys[('u1', AiProvider.gemini)] = 'key-u1'
      ..keys[('u2', AiProvider.gemini)] = 'key-u2';
    auth = FakeAuthService();
    unregisteredAtSignOut = null;
    final users = StreamController<String?>();
    // Not awaited: close() only completes once the stream is listened to.
    addTearDown(() {
      users.close();
    });
    container = ProviderContainer(
      overrides: [
        accountDeletionServiceProvider.overrideWithValue(service),
        if (clock != null)
          accountDeletionClockProvider.overrideWithValue(clock),
        pushMessagingServiceProvider.overrideWithValue(
          FakePushMessagingService(),
        ),
        deviceTokenServiceProvider.overrideWithValue(tokens),
        pushPreferencesServiceProvider.overrideWithValue(
          FakePushPreferencesService(),
        ),
        currentUserIdProvider.overrideWith((ref) => users.stream),
        aiApiKeyStorageServiceProvider.overrideWithValue(keys),
        authServiceProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    container.listen(accountDeletionViewModelProvider, (_, _) {});
    // The app keeps push alive for the whole session.
    container.listen(pushViewModelProvider, (_, _) {});
    container.listen(currentUserIdProvider, (_, _) {});
    users.add('u1');
    await pumpEventQueue();
  }

  AccountDeletion? read() => container.read(accountDeletionViewModelProvider);
  AccountDeletionViewModel vm() =>
      container.read(accountDeletionViewModelProvider.notifier);
  final waiting = AccountDeletion(deleteAfter: fakeDeleteAfter);

  test('not waiting: null', () async {
    await start();
    expect(read(), isNull);
    expect(service.fetchCalls, 1);
  });

  test('loads the waiting deletion at start', () async {
    await start(scheduled: waiting);
    expect(read(), waiting);
  });

  test('a failed check keeps what was known', () async {
    await start(scheduled: waiting);
    service.fetchFails = true;

    await vm().refresh();

    expect(read(), waiting);
  });

  test('isDue follows the clock', () async {
    await start(scheduled: waiting, clock: () => fakeDeleteAfter);
    expect(vm().isDue(waiting), isTrue);

    await start(
      scheduled: waiting,
      clock: () => fakeDeleteAfter.subtract(const Duration(minutes: 1)),
    );
    expect(vm().isDue(waiting), isFalse);
  });

  group('requestDeletion', () {
    test('without the word Delete, nothing happens', () async {
      await start();

      await expectLater(
        vm().requestDeletion('Delet'),
        throwsA(
          isA<AccountDeletionException>().having(
            (e) => e.failure,
            'failure',
            AccountDeletionFailure.notConfirmed,
          ),
        ),
      );

      expect(service.requests, isEmpty);
      expect(service.signOutCalls, 0);
    });

    test('schedules it, removes this user\'s AI keys and the push token, '
        'then signs out everywhere', () async {
      await start();
      expect(tokens.registered, ['android:token-1']);

      final result = await vm().requestDeletion(' delete ');

      expect(service.requests, [' delete ']);
      expect(result.signedOut, isTrue);
      expect(result.deletion, waiting);
      expect(keys.keys.keys, [('u2', AiProvider.gemini)]);
      expect(unregisteredAtSignOut, ['token-1']);
      expect(service.signOutCalls, 1);
      expect(read(), isNull);
    });

    test('when signing out fails, the Keep screen takes over', () async {
      await start(signOutFails: true);

      final result = await vm().requestDeletion('Delete');

      expect(result.signedOut, isFalse);
      expect(read(), waiting);
    });

    test('a refused request (admin) changes nothing else', () async {
      await start();
      service.requestFailure = AccountDeletionFailure.adminAccount;

      await expectLater(
        vm().requestDeletion('Delete'),
        throwsA(
          isA<AccountDeletionException>().having(
            (e) => e.failure,
            'failure',
            AccountDeletionFailure.adminAccount,
          ),
        ),
      );

      expect(keys.keys, hasLength(2));
      expect(tokens.unregistered, isEmpty);
      expect(service.signOutCalls, 0);
    });
  });

  group('keepAccount', () {
    test('cancels the deletion', () async {
      await start(scheduled: waiting);

      await vm().keepAccount();

      expect(service.cancelCalls, 1);
      expect(read(), isNull);
    });

    test('too late: says so and stays waiting', () async {
      await start(scheduled: waiting);
      service.cancelFailure = AccountDeletionFailure.tooLate;

      await expectLater(
        vm().keepAccount(),
        throwsA(isA<AccountDeletionException>()),
      );

      expect(read(), waiting);
    });
  });

  test('signOut removes the push token, then signs out', () async {
    await start(scheduled: waiting);

    expect(await vm().signOut(), isTrue);

    expect(auth.signOutCalls, 1);
    expect(tokens.unregistered, ['token-1']);
  });
}
