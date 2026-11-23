import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/push/services/device_token_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/services/suspension_service.dart';
import 'package:faunawatch/features/suspension/viewmodels/account_suspension_viewmodel.dart';
import '../../push/fake_push_services.dart';
import '../fake_suspension_service.dart';

void main() {
  late FakeSuspensionService service;
  late ProviderContainer container;

  Future<void> start({
    AccountSuspension? active,
    DateTime Function()? clock,
    List<Override> overrides = const [],
  }) async {
    service = FakeSuspensionService(active: active);
    container = ProviderContainer(
      overrides: [
        suspensionServiceProvider.overrideWithValue(service),
        if (clock != null) suspensionClockProvider.overrideWithValue(clock),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    container.listen(accountSuspensionViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  AccountSuspension? read() =>
      container.read(accountSuspensionViewModelProvider);
  AccountSuspensionViewModel vm() =>
      container.read(accountSuspensionViewModelProvider.notifier);

  test('not suspended: null', () async {
    await start();
    expect(read(), isNull);
    expect(service.fetchCalls, 1);
  });

  test('loads the active suspension at start', () async {
    await start(active: lockedUntilLifted());
    expect(read(), lockedUntilLifted());
  });

  test('a live suspension or reactivation is picked up', () async {
    await start();

    await service.change(restrictedFor7Days());
    await pumpEventQueue();
    expect(read(), restrictedFor7Days());

    await service.change(null);
    await pumpEventQueue();
    expect(read(), isNull);
  });

  test('a failed check keeps what was known', () async {
    await start(active: restrictedFor7Days());
    service.fails = true;

    await vm().refresh();

    expect(read(), restrictedFor7Days());
  });

  test('checks again when the suspension ends', () async {
    final suspension = restrictedFor7Days();
    // Half a second before the re-check (end + 1 s) is due.
    await start(
      active: suspension,
      clock: () => suspension.endsAt!.add(const Duration(milliseconds: 500)),
    );
    expect(service.fetchCalls, 1);
    service.active = null;

    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(service.fetchCalls, 2);
    expect(read(), isNull);
  });

  group('sign out', () {
    late FakePushMessagingService push;
    late FakeDeviceTokenService tokens;
    late StreamController<String?> users;
    // The tokens already removed when the session was ended.
    List<String>? unregisteredAtSignOut;

    Future<FakeAuthService> startSignedIn({bool fails = false}) async {
      push = FakePushMessagingService();
      tokens = FakeDeviceTokenService();
      users = StreamController<String?>();
      // Not awaited: close() only completes once the stream is listened to.
      addTearDown(() {
        users.close();
      });
      unregisteredAtSignOut = null;
      final auth = FakeAuthService(
        fails: fails,
        onSignOut: () => unregisteredAtSignOut = List.of(tokens.unregistered),
      );
      await start(
        active: lockedUntilLifted(),
        overrides: [
          pushMessagingServiceProvider.overrideWithValue(push),
          deviceTokenServiceProvider.overrideWithValue(tokens),
          pushPreferencesServiceProvider.overrideWithValue(
            FakePushPreferencesService(),
          ),
          currentUserIdProvider.overrideWith((ref) => users.stream),
          authServiceProvider.overrideWithValue(auth),
        ],
      );
      // The app keeps push alive for the whole session.
      container.listen(pushViewModelProvider, (_, _) {});
      users.add('u1');
      await pumpEventQueue();
      expect(tokens.registered, ['android:token-1']);
      return auth;
    }

    test('removes the push token, then really signs out', () async {
      final auth = await startSignedIn();

      expect(await vm().signOut(), isTrue);

      expect(auth.signOutCalls, 1);
      expect(unregisteredAtSignOut, ['token-1']);
    });

    test('a failure says so and registers the token again', () async {
      final auth = await startSignedIn(fails: true);

      expect(await vm().signOut(), isFalse);

      expect(auth.signOutCalls, 1);
      expect(tokens.registered, ['android:token-1', 'android:token-1']);
    });
  });
}
