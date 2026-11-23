import 'dart:async';
import 'package:faunawatch/features/suspension/services/suspension_service.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_notice.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_header.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_preferences_drawer.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_action_card.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import '../../gallery/fake_gallery_service.dart';
import '../../feed/fake_feed_service.dart';
import '../fake_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/services/profile_reader_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/profile/views/edit_profile_view.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/profile/views/settings_view.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

void main() {
  Widget buildTestProfile({
    _FakeReader? reader,
    FakeProfileService? writer,
    _FakeKeyStorage? keyStorage,
    FakeGalleryService? gallery,
    ThemeData? theme,
    bool liveThemes = false,
  }) {
    return ProviderScope(
      overrides: [
        // Signed in but not suspended; the real service needs Supabase.
        suspensionServiceProvider.overrideWithValue(
          const SignedOutSuspensionService(),
        ),
        galleryServiceProvider.overrideWithValue(
          gallery ?? FakeGalleryService(),
        ),
        aiApiKeyStorageServiceProvider.overrideWithValue(
          keyStorage ?? _FakeKeyStorage(),
        ),
        windowSecurityServiceProvider.overrideWithValue(_FakeWindowSecurity()),
        currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
        profileReaderServiceProvider.overrideWithValue(reader ?? _FakeReader()),
        profileServiceProvider.overrideWithValue(
          writer ?? FakeProfileService(),
        ),
      ],
      child: liveThemes
          ? Consumer(
              builder: (context, ref, _) => MaterialApp(
                theme: ref.watch(appLightThemeProvider),
                darkTheme: ref.watch(appDarkThemeProvider),
                themeMode: ref.watch(themeModeProvider),
                home: const ProfileView(),
              ),
            )
          : MaterialApp(theme: theme, home: const ProfileView()),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Profile & preferences'));
    await tester.pumpAndSettle();
  }

  group('ProfileView', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('drawer palette changes reach profile and gallery in $mode', (
        tester,
      ) async {
        final gallery = FakeGalleryService(
          posts: [
            testPost('own', authorId: 'user-a', title: 'My eagle sighting'),
          ],
        );
        await tester.pumpWidget(
          buildTestProfile(gallery: gallery, liveThemes: true),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProfileView)),
          listen: false,
        );
        container.read(themeModeProvider.notifier).setThemeMode(mode);
        await tester.pumpAndSettle();
        for (final choice in [
          ('Forest Emerald', 'forest'),
          ('Apollo', 'apollo'),
        ]) {
          await openMenu(tester);
          await tester.tap(find.text('Change Theme'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(choice.$1));
          await tester.tap(find.text(choice.$1));
          await tester.pumpAndSettle();
          expect(
            container.read(settingsViewModelProvider).activePaletteId,
            choice.$2,
          );
          expect(container.read(themeModeProvider), mode);
          final theme = Theme.of(tester.element(find.byType(ProfileView)));
          final colors = theme.extension<AppPaletteColors>()!;
          final background = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(ProfileView),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Container &&
                        widget.decoration is BoxDecoration &&
                        (widget.decoration! as BoxDecoration).gradient
                            is LinearGradient,
                  ),
                )
                .first,
          );
          expect(
            ((background.decoration! as BoxDecoration).gradient!
                    as LinearGradient)
                .colors,
            mode == ThemeMode.dark
                ? [
                    colors.darkProfileGradientStart,
                    colors.darkProfileGradientEnd,
                  ]
                : [
                    colors.profileBackgroundGradientStart,
                    colors.profileBackgroundGradientEnd,
                  ],
          );
          final filter = tester.widget<PopupMenuButton>(
            find.descendant(
              of: find.byType(GalleryHeader),
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            ),
          );
          expect(filter.color, colors.galleryFilterButtonBackground);
          expect(
            tester.widget<Icon>(find.byIcon(Icons.tune_rounded)).color,
            colors.galleryTitleBlue,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.color == colors.galleryCardDetailsYellow,
            ),
            findsOneWidget,
          );
          expect(find.text('My eagle sighting'), findsOneWidget);
          await openMenu(tester);
          final action = tester
              .widgetList<ProfileActionCard>(find.byType(ProfileActionCard))
              .first;
          expect(
            action.iconColor,
            colors.resolve(const Color(0xFF0284C7), theme.colorScheme.primary),
          );
          expect(
            action.iconBackgroundColor,
            colors.resolve(
              const Color(0xFFE0F2FE),
              theme.colorScheme.primaryContainer,
            ),
          );
          expect(
            find.text('Accent palette: ${choice.$2.toUpperCase()}'),
            findsOneWidget,
          );
          await tester.tap(find.byTooltip('Close profile menu'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Profile & preferences'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('shows My Gallery directly below the profile header', (
      tester,
    ) async {
      final gallery = FakeGalleryService(
        posts: [
          testPost('own', authorId: 'user-a', title: 'My eagle sighting'),
        ],
      );
      await tester.pumpWidget(buildTestProfile(gallery: gallery));
      await tester.pumpAndSettle();
      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Change Theme'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.byTooltip('Profile & preferences'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(GalleryHeader)).dy, lessThan(350));
      await tester.scrollUntilVisible(
        find.byType(GalleryCard),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('My Gallery'), findsOneWidget);
      expect(find.text('My eagle sighting'), findsOneWidget);
      expect(find.byType(GalleryCard), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(gallery.pageRequests, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing a banner saves the preset and displays it', (
      tester,
    ) async {
      final writer = FakeProfileService();
      await tester.pumpWidget(buildTestProfile(writer: writer));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      final banner = find.bySemanticsLabel('Banner 2');
      await tester.tap(banner);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(writer.savedBanner, AppAssets.bannerSunset);
      expect(writer.savedColor, isNull);
      expect(find.byType(EditProfileView), findsNothing);
      expect(find.text('Edit Profile'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == AppAssets.bannerSunset,
        ),
        findsOneWidget,
      );
    });

    testWidgets('failed banner save keeps the editor open for retry', (
      tester,
    ) async {
      final writer = FakeProfileService()..succeeds = false;
      await tester.pumpWidget(buildTestProfile(writer: writer));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Banner 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileView), findsOneWidget);
      expect(
        find.text('Unable to save profile. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows loading, then a retryable error without sample content',
      (tester) async {
        final pending = Completer<ProfileData>();
        final reader = _FakeReader()..load = () => pending.future;
        await tester.pumpWidget(buildTestProfile(reader: reader));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('tweetybird'), findsNothing);
        pending.completeError(StateError('Unavailable'));
        await tester.pumpAndSettle();
        expect(find.text('Unable to load your profile.'), findsOneWidget);
        reader.load = null;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Tester'), findsOneWidget);
      },
    );

    testWidgets('bottom padding follows the nav bar inset', (tester) async {
      Future<double> bottomPadding(double inset) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(bottom: inset)),
            child: buildTestProfile(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(GalleryNotice),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final padding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byType(GalleryNotice),
                matching: find.byType(Padding),
              )
              .first,
        );
        return (padding.padding as EdgeInsets).bottom;
      }

      expect(await bottomPadding(0), 20);
      expect(await bottomPadding(90), 110);
    });

    testWidgets('hamburger menu holds profile actions and dismisses cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('pls dont be inluv wt sum1 else'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == AppAssets.avatarBunny,
        ),
        findsOneWidget,
      );
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Watching wildlife responsibly.'), findsOneWidget);
      await openMenu(tester);
      expect(find.byType(ProfilePreferencesDrawer), findsOneWidget);
      expect(find.text('APPEARANCE'), findsNothing);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Theme Mode')).dy,
        lessThan(tester.getTopLeft(find.text('Edit Profile')).dy),
      );
      expect(find.text('Change Theme'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.byTooltip('Close profile menu'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('My Gallery'), findsOneWidget);
    });

    testWidgets('tapping Edit Profile navigates to EditProfileView', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileView), findsOneWidget);
      expect(find.text('Profile Appearance'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('tapping Change Theme opens ThemePickerSheet', (tester) async {
      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.text('Change Theme'));
      await tester.pumpAndSettle();

      expect(
        find.text('Select a nature-inspired accent palette for FaunaWatch'),
        findsOneWidget,
      );
      expect(find.text('Forest Emerald'), findsOneWidget);
    });

    testWidgets('drawer Appearance card switches themeModeProvider', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestProfile(liveThemes: true));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileView)),
        listen: false,
      );

      await openMenu(tester);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets('tapping Settings navigates to SettingsView', (tester) async {
      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsView), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Theme Mode'), findsNothing);
      expect(find.text('Sign Out'), findsNothing);
    });

    testWidgets(
      'sidebar Sign Out shows confirmation dialog and redirects to WelcomeView',
      (tester) async {
        await tester.pumpWidget(buildTestProfile());
        await tester.pumpAndSettle();

        await openMenu(tester);
        expect(find.text('Sign Out'), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text('Sign Out')).dy,
          greaterThan(tester.getBottomLeft(find.text('Settings')).dy),
        );

        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Are you sure you want to sign out? You will need to log back in to access your reports and messages.',
          ),
          findsOneWidget,
        );

        final confirmButton = find.widgetWithText(ElevatedButton, 'Sign Out');
        expect(confirmButton, findsOneWidget);
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(find.byType(WelcomeView), findsOneWidget);
      },
    );

    testWidgets('phone-sized dark menu remains accessible and Back closes it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestProfile(theme: ThemeData.dark()));
      await tester.pumpAndSettle();
      await openMenu(tester);
      final drawer = find.byType(ProfilePreferencesDrawer);
      expect(Theme.of(tester.element(drawer)).brightness, Brightness.dark);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Theme'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('My Gallery'), findsOneWidget);
    });
  });
}

class _FakeReader implements ProfileReaderService {
  Future<ProfileData> Function()? load;

  @override
  Future<ProfileData> loadProfile(String userId) async => load != null
      ? load!()
      : const ProfileData(
          username: 'Tester',
          bio: 'Watching wildlife responsibly.',
          presetAvatar: AppAssets.avatarBunny,
          bannerAsset: AppAssets.bannerDay,
        );
}

class _FakeKeyStorage implements AiApiKeyStorageService {
  final Set<AiProvider> saved = {};

  @override
  Future<String?> readKey(String userId, AiProvider provider) async =>
      saved.contains(provider) ? 'secret' : null;

  @override
  Future<void> saveKey(
    String userId,
    AiProvider provider,
    String apiKey,
  ) async {
    saved.add(provider);
  }

  @override
  Future<void> deleteKey(String userId, AiProvider provider) async {
    saved.remove(provider);
  }

  @override
  Future<void> deleteAllKeys(String userId) async => saved.clear();
}

class _FakeWindowSecurity implements WindowSecurityService {
  @override
  Future<void> enableSecure() async {}

  @override
  Future<void> disableSecure() async {}
}
