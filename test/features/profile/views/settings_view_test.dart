import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/profile/services/posts_privacy_service.dart';
import 'package:faunawatch/features/profile/viewmodels/posts_privacy_viewmodel.dart';
import 'package:faunawatch/features/profile/views/change_password_view.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:faunawatch/features/settings/views/about_ai_reports_view.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';
import 'package:faunawatch/features/settings/views/help_and_feedback_view.dart';
import 'package:faunawatch/features/settings/views/privacy_policy_view.dart';
import 'package:faunawatch/features/profile/views/settings_view.dart';

void main() {
  Widget buildTestSettings() {
    return const ProviderScope(child: MaterialApp(home: SettingsView()));
  }

  group('SettingsView', () {
    testWidgets('renders Account, Privacy below Account, and preferences', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestSettings());

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Update your sign-in password'), findsOneWidget);
      expect(find.text('PRIVACY'), findsOneWidget);
      expect(find.text('Private posts'), findsOneWidget);
      expect(
        find.text(
          'Only you can see your posts on your profile. '
          'They still appear in the Feed and on the map.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settings_location_note')), findsOne);
      expect(find.textContaining('about 100 m'), findsOneWidget);
      expect(find.text('Show approximate location'), findsNothing);
      expect(find.text('Hide my name on reports'), findsNothing);
      expect(
        tester.getTopLeft(find.text('PRIVACY')).dy,
        greaterThan(tester.getBottomLeft(find.text('Change password')).dy),
      );
      expect(find.text('Theme Mode'), findsNothing);
      expect(find.text('Sign Out'), findsNothing);
    });

    group('Private posts', () {
      late _FakePostsPrivacy privacy;
      setUp(() => privacy = _FakePostsPrivacy());

      Widget buildSignedIn() => ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
          postsPrivacyServiceProvider.overrideWithValue(privacy),
          aiApiKeyStorageServiceProvider.overrideWithValue(_FakeKeyStorage()),
          aiPreferencesServiceProvider.overrideWithValue(
            FakePreferencesService(),
          ),
        ],
        child: const MaterialApp(home: SettingsView()),
      );

      Switch privateSwitch(WidgetTester tester) => tester.widget<Switch>(
        find.descendant(
          of: find.byKey(const ValueKey('settings_private_posts')),
          matching: find.byType(Switch),
        ),
      );

      testWidgets('shows the saved setting and saves a change', (tester) async {
        privacy.saved = true;
        await tester.pumpWidget(buildSignedIn());
        await tester.pumpAndSettle();
        expect(privateSwitch(tester).value, isTrue);

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(privacy.saves, [false]);
        expect(privateSwitch(tester).value, isFalse);
      });

      testWidgets('a failed save flips the switch back and says why', (
        tester,
      ) async {
        privacy.saveError = StateError('offline');
        await tester.pumpWidget(buildSignedIn());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(privateSwitch(tester).value, isFalse);
        expect(
          find.text(PostsPrivacyViewModel.saveFailedMessage),
          findsOneWidget,
        );
      });

      testWidgets('a failed load disables the switch until a retry works', (
        tester,
      ) async {
        privacy.loadError = StateError('offline');
        await tester.pumpWidget(buildSignedIn());
        await tester.pumpAndSettle();
        expect(privateSwitch(tester).onChanged, isNull);
        expect(
          find.text('Could not load this setting. Tap to try again.'),
          findsOneWidget,
        );

        privacy
          ..loadError = null
          ..saved = true;
        await tester.tap(find.text('Private posts'));
        await tester.pumpAndSettle();
        expect(privateSwitch(tester).onChanged, isNotNull);
        expect(privateSwitch(tester).value, isTrue);
      });
    });

    testWidgets('tapping Change password opens ChangePasswordView', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestSettings());

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordView), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Update password'), findsOneWidget);
    });
  });

  group('SettingsView AI keys', () {
    Widget buildWithKeys(_FakeKeyStorage keyStorage) {
      return ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
          postsPrivacyServiceProvider.overrideWithValue(_FakePostsPrivacy()),
          aiApiKeyStorageServiceProvider.overrideWithValue(keyStorage),
          aiBackupKeyStorageServiceProvider.overrideWithValue(
            FakeBackupKeyStorage(),
          ),
          aiPreferencesServiceProvider.overrideWithValue(
            FakePreferencesService(),
          ),
          windowSecurityServiceProvider.overrideWithValue(
            _FakeWindowSecurity(),
          ),
        ],
        child: const MaterialApp(home: SettingsView()),
      );
    }

    testWidgets('prompts setup when no key is saved', (tester) async {
      await tester.pumpWidget(buildWithKeys(_FakeKeyStorage()));
      await tester.pumpAndSettle();

      expect(find.text('AI Integration'), findsOneWidget);
      expect(find.text('SET UP'), findsOneWidget);
    });

    testWidgets('shows how many keys are saved', (tester) async {
      final keyStorage = _FakeKeyStorage()
        ..saved.addAll({AiProvider.groq, AiProvider.gemini});
      await tester.pumpWidget(buildWithKeys(keyStorage));
      await tester.pumpAndSettle();

      expect(find.text('2 KEYS'), findsOneWidget);
      expect(find.text('SET UP'), findsNothing);
    });

    testWidgets('tapping AI Integration opens the AI Integration screen', (
      tester,
    ) async {
      await tester.pumpWidget(buildWithKeys(_FakeKeyStorage()));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI Integration'));
      await tester.pumpAndSettle();

      expect(find.byType(AiIntegrationView), findsOneWidget);
      expect(find.text('AI provider'), findsOneWidget);
      expect(find.text('Test API'), findsOneWidget);
    });

    testWidgets('tapping About AI results opens AboutAiReportsView', (
      tester,
    ) async {
      await tester.pumpWidget(buildWithKeys(_FakeKeyStorage()));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('About AI results'), findsOneWidget);
      expect(
        find.text(
          'Preliminary guesses only, not veterinary or wildlife-authority advice',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('About AI results'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutAiReportsView), findsOneWidget);
      expect(find.text('About AI Reports'), findsOneWidget);
      expect(
        find.text('AI gives a first guess, not an answer'),
        findsOneWidget,
      );
      expect(find.text('What the AI looks at'), findsOneWidget);
      expect(find.text('What the labels mean'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Medium'), findsNothing);
      expect(find.text('Uncertain'), findsNothing);
      expect(find.text('What AI cannot do'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('If AI is not available'), findsOneWidget);
      expect(find.text('Your photos and AI'), findsOneWidget);
    });

    testWidgets(
      'About and Support shows Help and feedback and Privacy policy above FaunaWatch Version',
      (tester) async {
        await tester.pumpWidget(buildWithKeys(_FakeKeyStorage()));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(find.text('ABOUT AND SUPPORT'), findsOneWidget);
        expect(find.text('Help and feedback'), findsOneWidget);
        expect(find.text('How to report, and send us a note'), findsOneWidget);
        expect(find.text('Privacy policy'), findsOneWidget);
        expect(find.text('How your data and photos are used'), findsOneWidget);
        expect(find.text('FaunaWatch Version'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Help and feedback')).dy,
          lessThan(tester.getTopLeft(find.text('Privacy policy')).dy),
        );
        expect(
          tester.getTopLeft(find.text('Privacy policy')).dy,
          lessThan(tester.getTopLeft(find.text('FaunaWatch Version')).dy),
        );

        await tester.tap(find.text('Help and feedback'));
        await tester.pumpAndSettle();
        expect(find.byType(HelpAndFeedbackView), findsOneWidget);
        expect(find.text('Help and Feedback'), findsOneWidget);
        expect(find.text('How to report a sighting'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Privacy policy'));
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyPolicyView), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('Photos and wildlife reports'), findsOneWidget);
      },
    );
  });
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

class _FakePostsPrivacy implements PostsPrivacyService {
  bool saved = false;
  Object? loadError, saveError;
  final saves = <bool>[];

  @override
  Future<bool> load() async {
    if (loadError != null) throw loadError!;
    return saved;
  }

  @override
  Future<bool> save(bool isPrivate) async {
    if (saveError != null) throw saveError!;
    saves.add(isPrivate);
    return saved = isPrivate;
  }
}

class _FakeWindowSecurity implements WindowSecurityService {
  @override
  Future<void> enableSecure() async {}

  @override
  Future<void> disableSecure() async {}
}
