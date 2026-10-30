import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';
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
        mapboxMapCanvasBuilderProvider.overrideWithValue(
          const _FakeMapboxMapCanvasBuilder(),
        ),
        mapboxMapServiceProvider.overrideWithValue(_FakeMapboxMapService()),
        profilePictureViewModelProvider.overrideWith(
          _FakeProfilePictureViewModel.new,
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

      // Feed view and its tabs have the header
      expect(find.byType(ShellHeader), findsOneWidget);
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellHeader), findsOneWidget);

      // Switch to Chats: header disappears
      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellHeader), findsNothing);

      // Switch back to Feed: header reappears
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellHeader), findsOneWidget);
    });

    testWidgets('moves Gallery and Map from the nav bar into feed tabs', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      final navBar = find.byType(ShellNavBar);

      for (final label in ['Feed', 'Chats', 'Notifs', 'Profile']) {
        expect(
          find.descendant(of: navBar, matching: find.text(label)),
          findsOneWidget,
        );
      }
      for (final label in ['Gallery', 'Map']) {
        expect(
          find.descendant(of: navBar, matching: find.text(label)),
          findsNothing,
        );
      }
      expect(find.bySemanticsLabel('Add post'), findsOneWidget);
    });

    testWidgets('switches views when navigation items are tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());

      await tester.tap(find.text('Your Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryView), findsOneWidget);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityMapView), findsOneWidget);
      expect(find.text('Community map'), findsOneWidget);

      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(find.byType(MessagesView), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Add post'));
      await tester.pumpAndSettle();
      expect(find.text('Feature pending implementation'), findsOneWidget);

      await tester.tap(find.text('Notifs'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsView), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileView), findsOneWidget);

      // Returning to Feed keeps the selected tab
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedView), findsOneWidget);
      expect(find.text('Community map'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

      // Feed tab: not secure
      expect(windowSecurity.isSecure, isFalse);
      expect(windowSecurity.enableCalls, 0);

      // Profile tab: secure
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(windowSecurity.isSecure, isTrue);

      // Chats tab: not secure again
      await tester.tap(find.text('Chats'));
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

class _FakeMapboxMapCanvasBuilder implements MapboxMapCanvasBuilder {
  const _FakeMapboxMapCanvasBuilder();

  @override
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
  }) {
    return const SizedBox(key: Key('fake_mapbox_map'));
  }
}

class _FakeMapboxMapService implements MapboxMapService {
  @override
  Future<void> applyAppearance({
    required Brightness brightness,
    required bool is3dEnabled,
  }) async {}

  @override
  Future<void> attach(
    MapboxMap mapboxMap, {
    void Function(String)? onPostTap,
  }) async {}

  @override
  void detach() {}

  @override
  Future<void> showWarningDemo(
    DemoWarningLevel level, {
    bool recenter = false,
  }) async {}
}

class _FakeProfilePictureViewModel extends ProfilePictureViewModel {
  @override
  ProfilePictureState build() => const ProfilePictureState();
}
