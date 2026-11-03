import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/views/ai_key_setup_view.dart';
import 'package:faunawatch/features/terms/views/terms_consent_view.dart';

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        aiApiKeyStorageServiceProvider.overrideWithValue(_EmptyKeyStorage()),
        currentUserIdProvider.overrideWith((ref) => Stream.value('user-1')),
        windowSecurityServiceProvider.overrideWithValue(_NoopWindowSecurity()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TermsConsentView(),
                  ),
                ),
                child: const Text('Open terms'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openTerms(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.text('Open terms'));
    await tester.pumpAndSettle();
  }

  Finder continueButton() => find.text('I agree, continue  >');

  Future<void> tapCheckbox(WidgetTester tester, Finder label) async {
    await tester.scrollUntilVisible(
      label,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(label);
    await tester.pump();
  }

  group('TermsConsentView', () {
    testWidgets('expands one section at a time', (tester) async {
      await openTerms(tester);

      const neighbourDetails =
          'Only share photos you took yourself. No harassment, spam or '
          'misleading reports. We may remove posts that break these rules.';
      expect(find.text(neighbourDetails), findsNothing);

      await tester.tap(find.text('Be a good neighbour'));
      await tester.pumpAndSettle();
      expect(find.text(neighbourDetails), findsOneWidget);

      await tester.tap(find.text('Stay safe out there'));
      await tester.pumpAndSettle();
      expect(find.text(neighbourDetails), findsNothing);
      expect(find.textContaining('Keep a safe distance'), findsOneWidget);
    });

    testWidgets('continue stays disabled until both boxes are ticked', (
      tester,
    ) async {
      await openTerms(tester);

      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.byType(AiKeySetupView), findsNothing);

      await tapCheckbox(
        tester,
        find.text('I agree to the Terms of Service and Privacy Policy.'),
      );
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.byType(AiKeySetupView), findsNothing);

      await tapCheckbox(
        tester,
        find.textContaining('I understand AI results are preliminary'),
      );
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.byType(AiKeySetupView), findsOneWidget);
      expect(find.text('Power up FaunaLens'), findsOneWidget);
    });

    testWidgets('decline asks for confirmation before going back', (
      tester,
    ) async {
      await openTerms(tester);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Agreement needed'), findsOneWidget);

      await tester.tap(find.text('Review terms'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsConsentView), findsOneWidget);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsConsentView), findsNothing);
      expect(find.text('Open terms'), findsOneWidget);
    });
  });
}

class _EmptyKeyStorage implements AiApiKeyStorageService {
  @override
  Future<String?> readKey(String userId, AiProvider provider) async => null;

  @override
  Future<void> saveKey(
    String userId,
    AiProvider provider,
    String apiKey,
  ) async {}

  @override
  Future<void> deleteKey(String userId, AiProvider provider) async {}

  @override
  Future<void> deleteAllKeys(String userId) async {}
}

class _NoopWindowSecurity implements WindowSecurityService {
  @override
  Future<void> enableSecure() async {}

  @override
  Future<void> disableSecure() async {}
}
