import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/views/ai_backup_key_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';

const _user = 'user-a';

void main() {
  late FakeBackupKeyStorage backups;
  late FakeKeyStorage mainKeys;
  late _WindowSecurity windowSecurity;
  late _Links links;

  setUp(() {
    backups = FakeBackupKeyStorage();
    mainKeys = FakeKeyStorage();
    windowSecurity = _WindowSecurity();
    links = _Links();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value(_user)),
          aiBackupKeyStorageServiceProvider.overrideWithValue(backups),
          aiApiKeyStorageServiceProvider.overrideWithValue(mainKeys),
          windowSecurityServiceProvider.overrideWithValue(windowSecurity),
          externalLinkServiceProvider.overrideWithValue(links),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiBackupKeyView(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> typeKey(WidgetTester tester, String provider, String key) async {
    await tester.tap(find.text(provider));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), key);
    await tester.pump();
  }

  Future<void> agree(WidgetTester tester) async {
    await tester.tap(find.text('I agree to the AI Keys Agreement'));
    await tester.pump();
    await tester.tap(find.text('Agree & save key'));
    await tester.pumpAndSettle();
  }

  testWidgets('explains the backup and blocks screenshots while open', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Backup key'), findsOneWidget);
    expect(find.textContaining('tries this key once'), findsOneWidget);
    expect(find.text('Add key'), findsNWidgets(3));
    expect(windowSecurity.isSecure, isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(windowSecurity.isSecure, isFalse);
  });

  testWidgets('saves a backup only after agreeing, apart from main keys', (
    tester,
  ) async {
    await pump(tester);
    await typeKey(tester, 'Groq', '  gsk_backup  ');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Before we save your Groq key'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(backups.backups, isEmpty);

    // The field lost focus when the agreement opened; tap back into it.
    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await agree(tester);

    expect(backups.backups[_user], (AiProvider.groq, 'gsk_backup'));
    expect(mainKeys.keys, isEmpty);
    expect(find.text('Groq backup key saved.'), findsOneWidget);
    expect(find.text('Key added'), findsOneWidget);
    expect(find.text('gsk_backup'), findsNothing);
  });

  testWidgets('Done saves a typed key and closes', (tester) async {
    await pump(tester);
    await typeKey(tester, 'Gemini', 'AIza_backup');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await agree(tester);

    expect(backups.backups[_user], (AiProvider.gemini, 'AIza_backup'));
    expect(find.byType(AiBackupKeyView), findsNothing);
  });

  testWidgets('warns that another provider replaces the backup', (
    tester,
  ) async {
    backups.backups[_user] = (AiProvider.groq, 'gsk_old');
    await pump(tester);
    expect(find.byKey(const ValueKey('backup_replace_note')), findsNothing);

    await tester.tap(find.text('Groq'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backup_replace_note')), findsNothing);

    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    expect(
      find.text('Saving a Gemini key replaces your Groq backup key.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'AIza_new');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await agree(tester);
    expect(backups.backups[_user], (AiProvider.gemini, 'AIza_new'));
  });

  testWidgets('removes the backup after confirming', (tester) async {
    backups.backups[_user] = (AiProvider.openRouter, 'or_old');
    await pump(tester);

    await tester.tap(find.text('OpenRouter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove key'));
    await tester.pumpAndSettle();
    expect(find.text('Remove backup key?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(backups.backups, isNotEmpty);

    await tester.tap(find.text('Remove key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(backups.backups, isEmpty);
    expect(find.text('Key added'), findsNothing);
  });

  testWidgets('a failed save keeps the typed key and says so', (tester) async {
    backups.saveError = StateError('storage locked');
    await pump(tester);
    await typeKey(tester, 'Groq', 'gsk_backup');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await agree(tester);

    expect(backups.backups, isEmpty);
    expect(
      find.text('Could not save the backup key. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'gsk_backup',
    );
  });

  testWidgets('the key link opens the provider console', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Groq'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Where do I get a Groq key?'));
    await tester.pumpAndSettle();
    expect(links.opened, [AiProvider.groq.keyConsoleUri]);
  });
}

class _WindowSecurity implements WindowSecurityService {
  bool isSecure = false;
  @override
  Future<void> enableSecure() async => isSecure = true;
  @override
  Future<void> disableSecure() async => isSecure = false;
}

class _Links implements ExternalLinkService {
  final List<Uri> opened = [];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
