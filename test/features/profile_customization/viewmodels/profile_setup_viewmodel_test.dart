import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_setup_viewmodel.dart';

class _FakeProfileService implements ProfileService {
  bool shouldSucceed = true;
  String? savedUsername;
  String? savedBio;

  @override
  Future<bool> saveProfile({
    required String username,
    required String bio,
  }) async {
    savedUsername = username;
    savedBio = bio;
    return shouldSucceed;
  }

  @override
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  }) async {
    return shouldSucceed;
  }

  @override
  Future<bool> saveProfileBanner({String? bannerAsset, int? colorValue}) async {
    return shouldSucceed;
  }
}

void main() {
  group('ProfileSetupViewModel', () {
    test('initial state has empty fields and disabled continue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(profileSetupViewModelProvider);
      expect(state.username, '');
      expect(state.bio, '');
      expect(state.isContinueEnabled, false);
      expect(state.isSubmitting, false);
    });

    test(
      'updating username and bio modifies state and activates continue button',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(profileSetupViewModelProvider.notifier)
            .onUsernameChanged('FoxWatcher');
        expect(
          container.read(profileSetupViewModelProvider).username,
          'FoxWatcher',
        );
        expect(
          container.read(profileSetupViewModelProvider).isContinueEnabled,
          false,
        );

        container
            .read(profileSetupViewModelProvider.notifier)
            .onBioChanged('Observing forest wildlife daily.');
        expect(
          container.read(profileSetupViewModelProvider).bio,
          'Observing forest wildlife daily.',
        );
        expect(
          container.read(profileSetupViewModelProvider).isContinueEnabled,
          true,
        );
      },
    );

    test('submit returns false when fields are incomplete', () async {
      final fakeService = _FakeProfileService();
      final container = ProviderContainer(
        overrides: [profileServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(profileSetupViewModelProvider.notifier)
          .submit();
      expect(result, false);
      expect(fakeService.savedUsername, isNull);
    });

    test(
      'submit succeeds and calls service when valid inputs provided',
      () async {
        final fakeService = _FakeProfileService();
        final container = ProviderContainer(
          overrides: [profileServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(profileSetupViewModelProvider.notifier);
        notifier.onUsernameChanged('FloraFauna');
        notifier.onBioChanged('Botanist and nature photographer');

        final result = await notifier.submit();
        expect(result, true);
        expect(fakeService.savedUsername, 'FloraFauna');
        expect(fakeService.savedBio, 'Botanist and nature photographer');
      },
    );
  });
}
