import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/services/profile_reader_service.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/profile/views/edit_profile_view.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
import '../fake_profile_service.dart';

class _FakeProfileReader implements ProfileReaderService {
  _FakeProfileReader(this.profile);

  final ProfileData profile;

  @override
  Future<ProfileData> loadProfile(String userId) async => profile;
}

class _FakeImagePicker implements ImagePickerService {
  String? nextPath;

  @override
  Future<String?> pickImage() async => nextPath;
}

void main() {
  const initialProfile = ProfileData(
    username: 'username',
    bio: 'bio',
    presetAvatar: AppAssets.avatarTweety,
    bannerAsset: AppAssets.bannerSunset,
  );

  Future<ProviderContainer> pumpEditor(
    WidgetTester tester, {
    ProfileData profile = initialProfile,
    FakeProfileService? writer,
    _FakeImagePicker? imagePicker,
    Size viewport = const Size(390, 844),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
        profileReaderServiceProvider.overrideWithValue(
          _FakeProfileReader(profile),
        ),
        profileServiceProvider.overrideWithValue(
          writer ?? FakeProfileService(),
        ),
        imagePickerServiceProvider.overrideWithValue(
          imagePicker ?? _FakeImagePicker(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileViewModelProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditProfileView()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Color saveBarBackground(WidgetTester tester) {
    final bar = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('edit_profile_save_bar')),
    );
    return (bar.decoration! as BoxDecoration).color!;
  }

  Color saveBarTextColor(WidgetTester tester) {
    final label = tester.widget<Text>(find.text('Save Changes'));
    return label.style!.color!;
  }

  group('EditProfileView', () {
    for (final viewport in const [Size(360, 640), Size(390, 844)]) {
      testWidgets('fits on one non-scrollable screen at $viewport', (
        tester,
      ) async {
        await pumpEditor(tester, viewport: viewport);

        expect(find.text('Profile Appearance'), findsOneWidget);
        expect(find.text('Choose Avatar'), findsOneWidget);
        expect(find.text('Upload Image'), findsOneWidget);
        expect(find.text('Click to edit'), findsOneWidget);
        expect(find.text('8/20 characters'), findsOneWidget);
        expect(find.text('3/50 characters'), findsOneWidget);
        expect(find.text('Profile Banner'), findsOneWidget);
        expect(find.bySemanticsLabel('Banner 1'), findsOneWidget);
        expect(find.bySemanticsLabel('Banner 2'), findsOneWidget);
        expect(find.bySemanticsLabel('Banner 3'), findsOneWidget);
        for (var i = 1; i <= AppColors.bannerColors.length; i++) {
          expect(find.bySemanticsLabel('Banner color $i'), findsOneWidget);
        }
        expect(find.text('Save Changes'), findsOneWidget);
        // Save Changes bar is docked edge-to-edge at the very bottom of the screen.
        final saveRect = tester.getRect(
          find.byKey(const ValueKey('edit_profile_save_bar')),
        );
        expect(saveRect.left, 0);
        expect(saveRect.right, viewport.width);
        expect(saveRect.bottom, viewport.height);
        // Must not be scrollable on the main edit screen.
        expect(
          find.descendant(
            of: find.byType(EditProfileView),
            matching: find.byType(SingleChildScrollView),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(EditProfileView),
            matching: find.byType(ListView),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'Save Changes uses inactive colors until edited and reverts when undone',
      (tester) async {
        final writer = FakeProfileService();
        await pumpEditor(tester, writer: writer);

        expect(saveBarBackground(tester), const Color(0xFFFFF9DD));
        expect(saveBarTextColor(tester), const Color(0xFF8FA6B6));

        // Tapping while inactive does nothing.
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        expect(writer.savedBanner, isNull);

        // Editing username enables Save Changes with active colors.
        await tester.enterText(
          find.byKey(const ValueKey('edit_profile_username_field')),
          'new_spotter',
        );
        await tester.pumpAndSettle();
        expect(find.text('11/20 characters'), findsOneWidget);
        expect(saveBarBackground(tester), const Color(0xFFFECE01));
        expect(saveBarTextColor(tester), const Color(0xFF1A5DC9));

        // Reverting back to original username disables Save Changes again.
        await tester.enterText(
          find.byKey(const ValueKey('edit_profile_username_field')),
          'username',
        );
        await tester.pumpAndSettle();
        expect(saveBarBackground(tester), const Color(0xFFFFF9DD));
        expect(saveBarTextColor(tester), const Color(0xFF8FA6B6));
      },
    );

    testWidgets(
      'Choose Avatar picker and banner color swatch enable Save Changes',
      (tester) async {
        final writer = FakeProfileService();
        final container = await pumpEditor(tester, writer: writer);

        await tester.tap(find.text('Choose Avatar'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Avatar 1'));
        await tester.pumpAndSettle();

        expect(saveBarBackground(tester), const Color(0xFFFECE01));
        expect(saveBarTextColor(tester), const Color(0xFF1A5DC9));

        await tester.tap(find.bySemanticsLabel('Banner color 4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(writer.savedBanner, isNull);
        expect(writer.savedColor, AppColors.bannerColors[3].toARGB32());
        expect(
          container.read(profileViewModelProvider).requireValue.presetAvatar,
          AppAssets.spotterAvatars[0],
        );
      },
    );

    testWidgets('Upload Image delegates through ProfileViewModel', (
      tester,
    ) async {
      final picker = _FakeImagePicker()..nextPath = '/tmp/custom_avatar.jpg';
      final writer = FakeProfileService();
      final container = await pumpEditor(
        tester,
        writer: writer,
        imagePicker: picker,
      );

      await tester.tap(find.text('Upload Image'));
      await tester.pumpAndSettle();

      expect(saveBarBackground(tester), const Color(0xFFFECE01));
      expect(saveBarTextColor(tester), const Color(0xFF1A5DC9));

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final updated = container.read(profileViewModelProvider).requireValue;
      expect(updated.customImagePath, '/tmp/custom_avatar.jpg');
      expect(updated.presetAvatar, isNull);
      expect(writer.savedCustomImagePath, '/tmp/custom_avatar.jpg');
    });

    testWidgets('editing bio persists through ProfileService on Save Changes', (
      tester,
    ) async {
      final writer = FakeProfileService();
      final container = await pumpEditor(tester, writer: writer);

      await tester.enterText(
        find.byKey(const ValueKey('edit_profile_bio_field')),
        'Owl tracker',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(writer.savedUsername, 'username');
      expect(writer.savedBio, 'Owl tracker');
      expect(
        container.read(profileViewModelProvider).requireValue.bio,
        'Owl tracker',
      );
    });

    testWidgets('failed save restores previous profile state', (tester) async {
      final writer = FakeProfileService()..succeeds = false;
      final container = await pumpEditor(tester, writer: writer);

      await tester.enterText(
        find.byKey(const ValueKey('edit_profile_bio_field')),
        'Unsaved bio',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(container.read(profileViewModelProvider).requireValue.bio, 'bio');
      expect(
        find.text('Unable to save profile. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
