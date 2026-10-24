import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/shell/views/search_view.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_header.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_nav_bar.dart';

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
    testWidgets('renders custom header, nav bar, and default Feed view', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.byType(ShellHeader), findsOneWidget);
      expect(find.byType(ShellNavBar), findsOneWidget);
      expect(find.byType(FeedView), findsOneWidget);
      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets('header only appears on the feed view, not on other pages', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());

      // Feed view has the header
      expect(find.byType(ShellHeader), findsOneWidget);

      // Switch to Gallery: header disappears
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellHeader), findsNothing);
      expect(find.byType(GalleryView), findsOneWidget);

      // Switch to Map: header absent
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellHeader), findsNothing);

      // Switch back to Feed: header reappears
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellHeader), findsOneWidget);
    });

    testWidgets('renders all six navigation destinations', (tester) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Notifs'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('switches views when navigation items are tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());

      // Tap Gallery destination
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryView), findsOneWidget);

      // Tap Map destination
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.text('Map View'), findsOneWidget);

      // Tap Chats destination
      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(find.byType(MessagesView), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      // Tap Notifs destination
      await tester.tap(find.text('Notifs'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsView), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);

      // Tap Profile destination and let its async settings load settle
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileView), findsOneWidget);

      // Tap back to Feed destination
      await tester.tap(find.text('Feed'));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('AI provider keys'), findsOneWidget);

      // Tap back to Report destination
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedView), findsOneWidget);
      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets(
      'tapping search bar opens SearchView with custom header and pops back',
      (tester) async {
        await tester.pumpWidget(buildTestShell());

        await tester.tap(find.bySemanticsLabel('Search'));
        await tester.pumpAndSettle();

        expect(find.byType(SearchView), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);

        // Check where.webp is present in SearchView
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == AppAssets.whereIcon,
          ),
          findsOneWidget,
        );

        // Tap back chevron
        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();

        expect(find.byType(SearchView), findsNothing);
        expect(find.byType(ShellView), findsOneWidget);
      },
    );
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
