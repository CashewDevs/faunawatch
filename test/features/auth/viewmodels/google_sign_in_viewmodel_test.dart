import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/auth/models/auth_destination.dart';
import 'package:faunawatch/features/auth/services/google_auth_service.dart';
import 'package:faunawatch/features/auth/viewmodels/google_sign_in_viewmodel.dart';
import '../fake_google_auth_service.dart';

void main() {
  late FakeGoogleAuthService service;
  late ProviderContainer container;
  setUp(() {
    service = FakeGoogleAuthService();
    container = ProviderContainer(
      overrides: [googleAuthServiceProvider.overrideWithValue(service)],
    );
    container.listen(googleSignInViewModelProvider, (_, next) {});
  });
  tearDown(() async {
    container.dispose();
    await service.dispose();
  });

  test(
    'browser launch waits for session and prevents duplicate submissions',
    () async {
      final vm = container.read(googleSignInViewModelProvider.notifier);
      await vm.signIn();
      await vm.signIn();
      expect(service.launches, 1);
      expect(container.read(googleSignInViewModelProvider).isBusy, isTrue);
      expect(container.read(googleSignInViewModelProvider).destination, isNull);
    },
  );

  for (final target in [AuthDestination.home, AuthDestination.profileSetup]) {
    test('confirmed session routes to $target', () async {
      service.destination = target;
      await container.read(googleSignInViewModelProvider.notifier).signIn();
      service.events.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(googleSignInViewModelProvider).destination, target);
      expect(container.read(googleSignInViewModelProvider).isBusy, isFalse);
    });
  }

  test('launch failure and retry use a safe error message', () async {
    service.launchError = StateError('sensitive provider response');
    final vm = container.read(googleSignInViewModelProvider.notifier);
    await vm.signIn();
    expect(
      container.read(googleSignInViewModelProvider).error,
      'Google sign-in could not be completed. Please try again.',
    );
    service.launchError = null;
    await vm.signIn();
    expect(container.read(googleSignInViewModelProvider).error, isNull);
    expect(service.launches, 2);
  });

  test('false browser result resets loading', () async {
    service.opens = false;
    await container.read(googleSignInViewModelProvider.notifier).signIn();
    expect(container.read(googleSignInViewModelProvider).isBusy, isFalse);
    expect(container.read(googleSignInViewModelProvider).error, isNotNull);
  });

  test('callback errors and profile failures are handled', () async {
    final vm = container.read(googleSignInViewModelProvider.notifier);
    await vm.signIn();
    service.events.addError(StateError('provider denied'));
    expect(container.read(googleSignInViewModelProvider).isBusy, isFalse);
    service.resolveError = StateError('offline');
    await vm.signIn();
    service.events.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(googleSignInViewModelProvider).error, isNotNull);
  });

  test(
    'cancel ignores an in-flight profile resolution and allows retry',
    () async {
      final vm = container.read(googleSignInViewModelProvider.notifier);
      service.pendingResolution = Completer<AuthDestination>();
      await vm.signIn();
      service.events.add(null);
      vm.cancel();
      service.pendingResolution!.complete(AuthDestination.home);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(googleSignInViewModelProvider).destination, isNull);
      expect(container.read(googleSignInViewModelProvider).isBusy, isFalse);
      await vm.signIn();
      expect(service.launches, 2);
    },
  );

  testWidgets('missing callback times out with a retryable error', (
    tester,
  ) async {
    await container.read(googleSignInViewModelProvider.notifier).signIn();
    await tester.pump(const Duration(minutes: 3));
    expect(container.read(googleSignInViewModelProvider).isBusy, isFalse);
    expect(container.read(googleSignInViewModelProvider).error, isNotNull);
  });

  test('disposal ignores a pending callback resolution', () async {
    service.pendingResolution = Completer<AuthDestination>();
    await container.read(googleSignInViewModelProvider.notifier).signIn();
    service.events.add(null);
    container.dispose();
    service.pendingResolution!.complete(AuthDestination.home);
    await Future<void>.delayed(Duration.zero);
  });
}
