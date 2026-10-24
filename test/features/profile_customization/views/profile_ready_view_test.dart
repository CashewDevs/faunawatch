import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_banner_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_setup_viewmodel.dart';
import 'package:faunawatch/features/intro/views/intro_view.dart';
import 'package:faunawatch/features/profile_customization/views/profile_ready_view.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_preview_card.dart';

class _FakeProfileService implements ProfileService {
  @override
  Future<bool> saveProfile({
    required String username,
    required String bio,
  }) async => true;

  @override
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  }) async => true;

  @override
  Future<bool> saveProfileBanner({
    String? bannerAsset,
    int? colorValue,
  }) async => true;
}

void main() {
  Widget createWidgetUnderTest({
    String username = 'Tweetie',
    String bio = 'Bird watcher and nature lover',
    String? avatar = AppAssets.avatarTweety,
    String? banner = AppAssets.bannerSunset,
  }) {
    return ProviderScope(
      overrides: [
        profileServiceProvider.overrideWithValue(_FakeProfileService()),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          // Pre-populate viewmodels for previewing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(profileSetupViewModelProvider.notifier)
                .onUsernameChanged(username);
            ref.read(profileSetupViewModelProvider.notifier).onBioChanged(bio);
            if (avatar != null) {
              ref
                  .read(profilePictureViewModelProvider.notifier)
                  .selectPresetAvatar(avatar);
            }
            if (banner != null) {
              ref
                  .read(profileBannerViewModelProvider.notifier)
                  .selectBanner(banner);
            }
          });

          return MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileReadyView(),
          );
        },
      ),
    );
  }

  group('ProfileReadyView', () {
    testWidgets('renders title, subtitle, preview card, and proceed button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text("You're all set!"), findsOneWidget);
      expect(
        find.text("Don't worry, you can update this anytime in your profile!"),
        findsOneWidget,
      );
      expect(find.byType(ProfilePreviewCard), findsOneWidget);
      expect(find.bySemanticsLabel('Proceed'), findsOneWidget);
    });

    testWidgets('displays chosen username and bio in preview card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createWidgetUnderTest(
          username: 'WildWatcher',
          bio: 'Nature enthusiast',
        ),
      );
      await tester.pump();

      expect(find.text('WildWatcher'), findsOneWidget);
      expect(find.text('Nature enthusiast'), findsOneWidget);
    });

    testWidgets('tapping proceed button navigates to IntroView', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Proceed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(IntroView), findsOneWidget);
      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.text('Slide Up'), findsOneWidget);
    });
  });
}
