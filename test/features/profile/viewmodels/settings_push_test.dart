import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/push/services/device_token_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';
import '../../push/fake_push_services.dart';

/// Records whether the push token was already removed when sign-out ran.
class _OrderedAuth implements AuthService {
  _OrderedAuth(this.tokens, {this.fails = false});
  final FakeDeviceTokenService tokens;
  final bool fails;
  List<String>? unregisteredAtSignOut;

  @override
  Future<bool> login(String email, String password) async => true;
  @override
  Future<bool> signUp(String email, String password) async => true;
  @override
  Future<void> signOut() async {
    unregisteredAtSignOut = List.of(tokens.unregistered);
    if (fails) throw StateError('still signed in');
  }
}

void main() {
  late FakePushMessagingService push;
  late FakeDeviceTokenService tokens;
  late FakePushPreferencesService prefs;
  late StreamController<String?> users;

  ProviderContainer build(_OrderedAuth auth) {
    users = StreamController<String?>();
    final container = ProviderContainer(
      overrides: [
        pushMessagingServiceProvider.overrideWithValue(push),
        deviceTokenServiceProvider.overrideWithValue(tokens),
        pushPreferencesServiceProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(auth),
        currentUserIdProvider.overrideWith((ref) => users.stream),
      ],
    );
    addTearDown(() {
      container.dispose();
      users.close();
    });
    return container;
  }

  setUp(() {
    push = FakePushMessagingService();
    tokens = FakeDeviceTokenService();
    prefs = FakePushPreferencesService();
  });

  test('loads the per-device choice into the settings state', () async {
    prefs.enabled = false;
    final container = build(_OrderedAuth(tokens));
    container.listen(settingsViewModelProvider, (_, _) {});
    expect(
      container.read(settingsViewModelProvider).pushNotificationsEnabled,
      true,
    );
    await pumpEventQueue();
    expect(
      container.read(settingsViewModelProvider).pushNotificationsEnabled,
      isFalse,
    );
  });

  test('the switch persists and registers or unregisters', () async {
    final container = build(_OrderedAuth(tokens));
    container.listen(settingsViewModelProvider, (_, _) {});
    users.add('u1');
    await pumpEventQueue();
    expect(tokens.registered, ['android:token-1']);

    final settings = container.read(settingsViewModelProvider.notifier);
    await settings.togglePushNotifications(false);
    expect(prefs.enabled, isFalse);
    expect(tokens.unregistered, ['token-1']);
    expect(
      container.read(settingsViewModelProvider).pushNotificationsEnabled,
      isFalse,
    );

    await settings.togglePushNotifications(true);
    expect(prefs.enabled, isTrue);
    expect(tokens.registered, ['android:token-1', 'android:token-1']);
  });

  test('sign-out removes the token before the session ends', () async {
    final auth = _OrderedAuth(tokens);
    final container = build(auth);
    container.listen(settingsViewModelProvider, (_, _) {});
    users.add('u1');
    await pumpEventQueue();

    expect(
      await container.read(settingsViewModelProvider.notifier).signOut(),
      true,
    );
    expect(auth.unregisteredAtSignOut, ['token-1']);
  });

  test('a failed sign-out registers the device again', () async {
    final auth = _OrderedAuth(tokens, fails: true);
    final container = build(auth);
    container.listen(settingsViewModelProvider, (_, _) {});
    users.add('u1');
    await pumpEventQueue();

    expect(
      await container.read(settingsViewModelProvider.notifier).signOut(),
      false,
    );
    expect(tokens.registered.length, 2);
  });
}
