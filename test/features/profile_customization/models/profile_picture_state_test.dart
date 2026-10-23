import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/profile_customization/models/profile_picture_state.dart';

void main() {
  group('ProfilePictureState', () {
    test('initial state defaults to unselected and disabled continue', () {
      const state = ProfilePictureState();
      expect(state.selectedPresetAvatar, isNull);
      expect(state.customImagePath, isNull);
      expect(state.isContinueEnabled, false);
      expect(state.isCustomImageSelected, false);
      expect(state.isSubmitting, false);
      expect(state.errorMessage, isNull);
    });

    test('isContinueEnabled is true when preset avatar is selected', () {
      const state = ProfilePictureState(
        selectedPresetAvatar: 'assets/images/panda.webp',
      );
      expect(state.isContinueEnabled, true);
      expect(state.isCustomImageSelected, false);
    });

    test('isContinueEnabled is true when custom image is selected', () {
      const state = ProfilePictureState(
        customImagePath: '/storage/emulated/0/DCIM/photo.jpg',
      );
      expect(state.isContinueEnabled, true);
      expect(state.isCustomImageSelected, true);
    });

    test('copyWith properly clears previous selection when requested', () {
      const initial = ProfilePictureState(
        selectedPresetAvatar: 'assets/images/panda.webp',
      );
      final updated = initial.copyWith(
        customImagePath: '/storage/emulated/0/DCIM/custom.png',
        clearPreset: true,
      );

      expect(updated.selectedPresetAvatar, isNull);
      expect(updated.customImagePath, '/storage/emulated/0/DCIM/custom.png');
      expect(updated.isContinueEnabled, true);
      expect(updated.isCustomImageSelected, true);
    });
  });
}
