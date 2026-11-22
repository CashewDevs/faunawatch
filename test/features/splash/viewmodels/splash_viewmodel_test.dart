import 'dart:async';

import 'package:faunawatch/features/auth/services/google_auth_service.dart';
import 'package:faunawatch/features/auth/models/auth_destination.dart';
import '../../auth/fake_google_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/splash/viewmodels/splash_viewmodel.dart';

void main() {
  late FakeGoogleAuthService service;
  late ProviderContainer container;

  setUp(() {
    service = FakeGoogleAuthService();
    container = ProviderContainer(
      overrides: [googleAuthServiceProvider.overrideWithValue(service)],
    );
  });

  tearDown(() {
    container.dispose();
    service.dispose();
  });

  SplashViewModel viewModel() =>
      container.read(splashViewModelProvider.notifier);
  SplashState state() => container.read(splashViewModelProvider);
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  for (final target in [AuthDestination.home, AuthDestination.profileSetup]) {
    test('restores $target on startup', () async {
      service.destination = target;
      await viewModel().initializeApp();
      expect(
        state(),
        target == AuthDestination.home
            ? SplashState.home
            : SplashState.profileSetup,
      );
    });
  }

  test('restoration failure can be retried', () async {
    service.resolveError = StateError('offline');
    await viewModel().initializeApp();
    expect(state(), SplashState.failed);
    service.resolveError = null;
    await viewModel().initializeApp();
    expect(state(), SplashState.complete);
  });

  test('a failure waits for the intro before showing Retry', () async {
    service.resolveError = StateError('offline');
    final intro = Completer<void>();
    final done = viewModel().initializeApp(introFinished: intro.future);
    await settle();
    expect(state(), SplashState.initializing);
    intro.complete();
    await done;
    expect(state(), SplashState.failed);
  });

  group('SplashViewModel', () {
    test('initial state is initializing', () {
      expect(state(), SplashState.initializing);
    });

    test('starts the sign-in check while the intro is still playing', () async {
      final intro = Completer<void>();
      final done = viewModel().initializeApp(introFinished: intro.future);
      await settle();

      // The check already ran, but the screen waits for the intro.
      expect(service.resolutions, 1);
      expect(state(), SplashState.initializing);

      intro.complete();
      await done;
      expect(state(), SplashState.complete);
    });

    test('waits for a slow sign-in check after the intro ends', () async {
      service.pendingResolution = Completer<AuthDestination>();
      final done = viewModel().initializeApp(introFinished: Future.value());
      await settle();
      expect(state(), SplashState.initializing);

      service.pendingResolution!.complete(AuthDestination.home);
      await done;
      expect(state(), SplashState.home);
      expect(service.resolutions, 1);
    });
  });
}
