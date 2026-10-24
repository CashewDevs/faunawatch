import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/profile/views/edit_profile_view.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/profile/views/settings_view.dart';

void main() {
  Widget buildTestProfile() {
    return const ProviderScope(child: MaterialApp(home: ProfileView()));
  }

  group('ProfileView', () {
    testWidgets('renders profile header with username, bio, and action cards', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestProfile());

      expect(find.text('tweetybird'), findsOneWidget);
      expect(find.text('pls dont be inluv wt sum1 else'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Theme'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('tapping Edit Profile navigates to EditProfileView', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestProfile());

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileView), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('tapping Change Theme opens ThemePickerSheet', (tester) async {
      await tester.pumpWidget(buildTestProfile());

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

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsView), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
