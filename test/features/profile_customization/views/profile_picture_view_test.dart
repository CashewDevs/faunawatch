import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/profile_customization/views/profile_picture_view.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_continue_button.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/spotter_avatar_item.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/upload_picture_button.dart';

class _FakeImagePickerService implements ImagePickerService {
  String? pickedPath = 'assets/images/garfield.webp';

  @override
  Future<String?> pickImage() async {
    return pickedPath;
  }
}

void main() {
  Widget createWidgetUnderTest({ImagePickerService? imagePickerService}) {
    return ProviderScope(
      overrides: [
        if (imagePickerService != null)
          imagePickerServiceProvider.overrideWithValue(imagePickerService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProfilePictureView(),
      ),
    );
  }

  group('ProfilePictureView', () {
    testWidgets('renders title, subtitle, 9 avatars, and upload button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Your Profile Picture'), findsOneWidget);
      expect(
        find.text('Select a spotter icon or upload a custom image.'),
        findsOneWidget,
      );
      expect(find.text('Upload a pic!'), findsOneWidget);
      expect(find.byType(SpotterAvatarItem), findsNWidgets(9));
      expect(find.byType(UploadPictureButton), findsOneWidget);
      expect(find.byType(ProfileContinueButton), findsOneWidget);
    });

    testWidgets('Continue button activates when an avatar is tapped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      var buttonWidget = tester.widget<ProfileContinueButton>(
        find.byType(ProfileContinueButton),
      );
      expect(buttonWidget.isEnabled, false);

      // Tap first avatar (panda)
      await tester.tap(find.byType(SpotterAvatarItem).first);
      await tester.pump();

      buttonWidget = tester.widget<ProfileContinueButton>(
        find.byType(ProfileContinueButton),
      );
      expect(buttonWidget.isEnabled, true);

      // Verify the first avatar has orange border
      final firstAvatar = tester.widget<SpotterAvatarItem>(
        find.byType(SpotterAvatarItem).first,
      );
      expect(firstAvatar.isSelected, true);
    });

    testWidgets('Continue button activates when custom image is chosen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakePicker = _FakeImagePickerService();
      await tester.pumpWidget(
        createWidgetUnderTest(imagePickerService: fakePicker),
      );

      await tester.tap(find.byType(UploadPictureButton));
      await tester.pump();

      final uploadButton = tester.widget<UploadPictureButton>(
        find.byType(UploadPictureButton),
      );
      expect(uploadButton.isSelected, true);

      final buttonWidget = tester.widget<ProfileContinueButton>(
        find.byType(ProfileContinueButton),
      );
      expect(buttonWidget.isEnabled, true);
    });

    testWidgets(
      'tapping active Continue button navigates to ProfileBannerView',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        await tester.tap(find.byType(SpotterAvatarItem).at(2)); // tweety
        await tester.pump();

        await tester.tap(find.byType(ProfileContinueButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Profile Banner'), findsOneWidget);
        expect(
          find.text('Choose a preset style or pick a color'),
          findsOneWidget,
        );
      },
    );
  });
}
