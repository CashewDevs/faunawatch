import 'dart:async';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
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

void main() {
  Widget buildTestProfile({_FakeReader? reader, FakeProfileService? writer}) {
    return ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
        profileReaderServiceProvider.overrideWithValue(reader ?? _FakeReader()),
        profileServiceProvider.overrideWithValue(
          writer ?? FakeProfileService(),
        ),
      ],
      child: const MaterialApp(home: ProfileView()),
    );
  }

  group('ProfileView', () {
    testWidgets('editing a banner saves the preset and displays it', (
      tester,
    ) async {
      final writer = FakeProfileService();
      await tester.pumpWidget(buildTestProfile(writer: writer));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      final banner = find.bySemanticsLabel('Banner 2');
      await tester.ensureVisible(banner);
      await tester.tap(banner);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writer.savedBanner, AppAssets.bannerSunset);
      expect(writer.savedColor, isNull);
      expect(find.byType(EditProfileView), findsNothing);
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
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
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

    testWidgets('renders profile header with username, bio, and action cards', (
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
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Theme'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('tapping Edit Profile navigates to EditProfileView', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileView), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('tapping Change Theme opens ThemePickerSheet', (tester) async {
      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Theme'));
      await tester.pumpAndSettle();

      expect(
        find.text('Select a nature-inspired accent palette for FaunaWatch'),
        findsOneWidget,
      );
      expect(find.text('Forest Emerald'), findsOneWidget);
    });

    testWidgets('tapping Settings navigates to SettingsView', (tester) async {
      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsView), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
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
          presetAvatar: AppAssets.avatarBunny,
          bannerAsset: AppAssets.bannerDay,
        );
}
