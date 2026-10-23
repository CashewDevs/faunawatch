import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

void main() {
  late _FakeWindowSecurityService windowSecurity;

  setUp(() {
    windowSecurity = _FakeWindowSecurityService();
  });

  Widget buildTestShell() {
    return ProviderScope(
      overrides: [
        windowSecurityServiceProvider.overrideWithValue(windowSecurity),
        aiApiKeyStorageServiceProvider.overrideWithValue(
          _FakeAiApiKeyStorageService(),
        ),
      ],
      child: const MaterialApp(home: ShellView()),
    );
  }

  group('ShellView', () {
    testWidgets('renders header with FaunaWatch title', (tester) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.text('FaunaWatch'), findsOneWidget);
    });

    testWidgets('renders all four navigation destinations', (tester) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('displays Report placeholder by default', (tester) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.text('Report View'), findsOneWidget);
    });

    testWidgets('switches views when navigation items are tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());

      // Tap Map destination
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(find.text('Map View'), findsOneWidget);

      // Tap Alerts destination
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();

      expect(find.text('Alerts View'), findsOneWidget);

      // Tap Profile destination and let its async settings load settle
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('AI provider keys'), findsOneWidget);

      // Tap back to Report destination
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.text('Report View'), findsOneWidget);
    });

    testWidgets('enables window security only while Profile is selected', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();

      // Report tab: not secure
      expect(windowSecurity.isSecure, isFalse);
      expect(windowSecurity.enableCalls, 0);

      // Profile tab: secure
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(windowSecurity.isSecure, isTrue);

      // Map tab: not secure again
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(windowSecurity.isSecure, isFalse);

      // Removing the shell while on Profile clears security
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(windowSecurity.isSecure, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(windowSecurity.isSecure, isFalse);
    });
  });
}

class _FakeWindowSecurityService implements WindowSecurityService {
  bool isSecure = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enableSecure() async {
    enableCalls++;
    isSecure = true;
  }

  @override
  Future<void> disableSecure() async {
    disableCalls++;
    isSecure = false;
  }
}

class _FakeAiApiKeyStorageService implements AiApiKeyStorageService {
  final Map<(String, AiProvider), String> keys = {};

  @override
  Future<String?> readKey(String userId, AiProvider provider) async =>
      keys[(userId, provider)];

  @override
  Future<void> saveKey(
    String userId,
    AiProvider provider,
    String apiKey,
  ) async {
    keys[(userId, provider)] = apiKey;
  }

  @override
  Future<void> deleteKey(String userId, AiProvider provider) async {
    keys.remove((userId, provider));
  }

  @override
  Future<void> deleteAllKeys(String userId) async {
    keys.removeWhere((key, _) => key.$1 == userId);
  }
}
