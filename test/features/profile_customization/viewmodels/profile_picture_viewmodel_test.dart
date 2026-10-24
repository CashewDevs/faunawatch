import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';

class _FakeProfileService implements ProfileService {
  bool shouldSucceed = true;
  String? savedPresetAvatar;
  String? savedCustomImagePath;

  @override
  Future<bool> saveProfile({
    required String username,
    required String bio,
  }) async {
    return shouldSucceed;
  }

  @override
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  }) async {
    savedPresetAvatar = presetAvatar;
    savedCustomImagePath = customImagePath;
    return shouldSucceed;
  }

  @override
  Future<bool> saveProfileBanner({String? bannerAsset, int? colorValue}) async {
    return shouldSucceed;
  }
}

class _FakeImagePickerService implements ImagePickerService {
  String? pickedPath = '/storage/emulated/0/Pictures/avatar.jpg';

  @override
  Future<String?> pickImage() async {
    return pickedPath;
  }
}

void main() {
  group('ProfilePictureViewModel', () {
    test('initial state has no avatar and continue disabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(profilePictureViewModelProvider);
      expect(state.selectedPresetAvatar, isNull);
      expect(state.customImagePath, isNull);
      expect(state.isContinueEnabled, false);
    });

    test('selectPresetAvatar sets avatar and activates continue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(profilePictureViewModelProvider.notifier)
          .selectPresetAvatar('assets/images/panda.webp');

      final state = container.read(profilePictureViewModelProvider);
      expect(state.selectedPresetAvatar, 'assets/images/panda.webp');
      expect(state.customImagePath, isNull);
      expect(state.isContinueEnabled, true);
    });

    test(
      'pickCustomImage sets image and overrides any preset avatar selection',
      () async {
        final fakePicker = _FakeImagePickerService();
        final container = ProviderContainer(
          overrides: [imagePickerServiceProvider.overrideWithValue(fakePicker)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          profilePictureViewModelProvider.notifier,
        );
        notifier.selectPresetAvatar('assets/images/garfield.webp');

        await notifier.pickCustomImage();

        final state = container.read(profilePictureViewModelProvider);
        expect(state.selectedPresetAvatar, isNull);
        expect(
          state.customImagePath,
          '/storage/emulated/0/Pictures/avatar.jpg',
        );
        expect(state.isContinueEnabled, true);
      },
    );

    test('submit calls profile service with selected avatar', () async {
      final fakeService = _FakeProfileService();
      final container = ProviderContainer(
        overrides: [profileServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(profilePictureViewModelProvider.notifier);
      notifier.selectPresetAvatar('assets/images/bunny.webp');

      final result = await notifier.submit();
      expect(result, true);
      expect(fakeService.savedPresetAvatar, 'assets/images/bunny.webp');
      expect(fakeService.savedCustomImagePath, isNull);
    });
  });
}
