import 'package:camera/camera.dart';
import 'package:faunawatch/features/fauna_lens/services/fauna_lens_camera_service.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/views/fauna_lens_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/community_map/models/map_focus.dart';
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
  late _FakeCamera camera;

  setUp(() {
    windowSecurity = _FakeWindowSecurityService();
    camera = _FakeCamera();
  });

  Widget buildTestShell({bool reduceMotion = false}) {
    return ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
        windowSecurityServiceProvider.overrideWithValue(windowSecurity),
        faunaLensCameraServiceProvider.overrideWithValue(camera),
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
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const ShellView(),
      ),
    );
  }

  double tabFadeOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(find.byKey(const Key('shell_tab_fade')))
      .opacity
      .value;

  double squircleCenter(WidgetTester tester) =>
      tester.getCenter(find.byKey(const Key('nav_selection_squircle'))).dx;

  double labelCenter(WidgetTester tester, String label) => tester
      .getCenter(
        find.descendant(
          of: find.byType(ShellNavBar),
          matching: find.text(label),
        ),
      )
      .dx;

  group('ShellView', () {
    testWidgets('renders custom header, nav bar, and default Feed view', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      // The feed shows a spinner until its first page (empty here) arrives.
      await tester.pump();

      expect(find.byType(ShellHeader), findsOneWidget);
      expect(find.byType(ShellNavBar), findsOneWidget);
      expect(find.byType(FeedView), findsOneWidget);
      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets('header only appears on Feed and Map, not on other pages', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());

      // Feed and Map have the header
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

    testWidgets(
      'system Back returns to the previous tab and asks before exiting',
      (tester) async {
        Future<void> pressBack() async {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/navigation',
            const JSONMethodCodec().encodeMethodCall(
              const MethodCall('popRoute'),
            ),
            (_) {},
          );
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(buildTestShell());
        await tester.tap(find.text('Chats'));
        await tester.pumpAndSettle();
        expect(find.byType(ShellHeader), findsNothing);

        await pressBack();
        expect(find.byType(ShellView), findsOneWidget);
        expect(find.byType(ShellHeader), findsOneWidget);
        expect(find.text('Press back again to exit'), findsNothing);

        await pressBack();
        expect(find.byType(ShellView), findsOneWidget);
        expect(find.text('Press back again to exit'), findsOneWidget);
      },
    );

    testWidgets(
      'the bar is Feed · Map | + | Chats · Profile with "+" centred',
      (tester) async {
        await tester.pumpWidget(buildTestShell());
        final navBar = find.byType(ShellNavBar);

        for (final label in ['Feed', 'Map', 'Chats', 'Profile']) {
          expect(
            find.descendant(of: navBar, matching: find.text(label)),
            findsOneWidget,
          );
        }
        // Notifications open from the top bar's bell; Gallery is in Profile.
        for (final label in ['Gallery', 'Notifs', 'Notifications', 'For You']) {
          expect(
            find.descendant(of: navBar, matching: find.text(label)),
            findsNothing,
          );
        }
        final add = tester.getCenter(find.bySemanticsLabel('Add post')).dx;
        expect(add, closeTo(tester.getSize(navBar).width / 2, 0.5));
        expect(
          labelCenter(tester, 'Feed'),
          lessThan(labelCenter(tester, 'Map')),
        );
        expect(labelCenter(tester, 'Map'), lessThan(add));
        expect(add, lessThan(labelCenter(tester, 'Chats')));
        expect(
          labelCenter(tester, 'Chats'),
          lessThan(labelCenter(tester, 'Profile')),
        );
        // Two tabs on each side, mirrored around "+".
        expect(
          add - labelCenter(tester, 'Map'),
          closeTo(labelCenter(tester, 'Chats') - add, 0.5),
        );
      },
    );

    testWidgets('Profile uses an outline person icon, filled when selected', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNothing);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    });

    testWidgets('the squircle glides from the current tab to the next', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();
      final feed = labelCenter(tester, 'Feed');
      final chats = labelCenter(tester, 'Chats');
      expect(squircleCenter(tester), closeTo(feed, 0.5));

      await tester.tap(find.text('Chats'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Part of the way there.
      expect(squircleCenter(tester), greaterThan(feed + 1));
      expect(squircleCenter(tester), lessThan(chats - 1));

      await tester.pumpAndSettle();
      expect(squircleCenter(tester), closeTo(chats, 0.5));
    });

    testWidgets('the opened tab fades in', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();
      expect(tabFadeOpacity(tester), 1);

      await tester.tap(find.text('Chats'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tabFadeOpacity(tester), lessThan(1));

      await tester.pumpAndSettle();
      expect(tabFadeOpacity(tester), 1);
      expect(find.byType(MessagesView), findsOneWidget);
    });

    testWidgets('the map appears at once while the squircle still glides', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();
      final feed = labelCenter(tester, 'Feed');

      await tester.tap(find.text('Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Fading the native map view makes it stutter, so it is not faded.
      expect(tabFadeOpacity(tester), 1);
      expect(squircleCenter(tester), greaterThan(feed + 1));
      expect(squircleCenter(tester), lessThan(labelCenter(tester, 'Map') - 1));

      // Leaving the map still fades the next tab in.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chats'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tabFadeOpacity(tester), lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('nothing animates when the device asks for less motion', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell(reduceMotion: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chats'));
      await tester.pump();
      expect(tabFadeOpacity(tester), 1);
      expect(
        squircleCenter(tester),
        closeTo(labelCenter(tester, 'Chats'), 0.5),
      );
    });

    testWidgets('the map is created on first use and kept across tabs', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();
      expect(find.byType(CommunityMapView, skipOffstage: false), findsNothing);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityMapView), findsOneWidget);
      final state = tester.state(find.byType(CommunityMapView));

      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityMapView), findsNothing);
      expect(find.byType(FeedView), findsOneWidget);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(CommunityMapView)), same(state));
    });

    testWidgets('switches views when navigation items are tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());

      expect(find.byType(GalleryView), findsNothing);
      expect(find.text('Gallery'), findsNothing);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityMapView), findsOneWidget);
      expect(find.byTooltip('About this map'), findsOneWidget);

      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(find.byType(MessagesView), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileView), findsOneWidget);
      expect(find.byType(GalleryView), findsOneWidget);
      expect(find.text('My Gallery'), findsOneWidget);

      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedView), findsOneWidget);
      expect(find.byTooltip('About this map'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the bell opens notifications on top and Back returns to the feed',
      (tester) async {
        await tester.pumpWidget(buildTestShell());
        await tester.pump();

        // The bell is in the top bar on both feed tabs.
        await tester.tap(find.text('Map'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Notifications'), findsOneWidget);

        await tester.tap(find.byTooltip('Notifications'));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationsView), findsOneWidget);
        // A page on top: the shell's bars are hidden.
        expect(find.byType(ShellNavBar), findsNothing);
        expect(find.byType(ShellHeader), findsNothing);

        // System Back closes the page and is not a shell step.
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/navigation',
          const JSONMethodCodec().encodeMethodCall(
            const MethodCall('popRoute'),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
        expect(find.byType(NotificationsView), findsNothing);
        expect(find.byType(ShellNavBar), findsOneWidget);
        expect(find.byTooltip('About this map'), findsOneWidget);
        expect(find.text('Press back again to exit'), findsNothing);
      },
    );

    testWidgets('the bell is not shown on the other tabs', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifications'), findsNothing);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifications'), findsNothing);
    });

    testWidgets('the header has no camera button', (tester) async {
      await tester.pumpWidget(buildTestShell());
      expect(find.bySemanticsLabel('Open camera'), findsNothing);
      expect(find.byIcon(Icons.camera_alt_rounded), findsNothing);
    });

    testWidgets('"+" opens the FaunaLens camera and closing it returns', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Add post'));
      await tester.pumpAndSettle();
      expect(find.byType(FaunaLensView), findsOneWidget);
      expect(camera.starts, 1);

      await tester.tap(find.bySemanticsLabel('Close camera'));
      await tester.pumpAndSettle();
      expect(find.byType(FaunaLensView), findsNothing);
      expect(find.byType(FeedView), findsOneWidget);
      expect(find.text('Create post'), findsNothing);
    });

    testWidgets('"+" starts a fresh post each time', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShellView)),
      );
      container
          .read(createPostViewModelProvider.notifier)
          .edit(description: 'Left over from an abandoned post');

      await tester.tap(find.bySemanticsLabel('Add post'));
      await tester.pumpAndSettle();
      expect(container.read(createPostViewModelProvider).description, isEmpty);
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
    testWidgets('screenshots stay allowed on every tab, Profile included', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();
      for (final tab in ['Profile', 'Chats', 'Profile']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(windowSecurity.isSecure, isFalse);
      }
      await tester.pumpWidget(const SizedBox());
      expect(windowSecurity.enableCalls, 0);
    });
  });
}

class _FakeCamera implements FaunaLensCameraService {
  int starts = 0;

  @override
  CameraController? get controller => null;

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> stop() async {}

  @override
  Future<bool> switchLens() async => true;

  @override
  Future<void> setFlash({required bool isOn}) async {}

  @override
  Future<String> takePicture() async => 'camera.jpg';
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
    OnMapIdleListener? onMapIdle,
  }) {
    return const SizedBox(key: Key('fake_mapbox_map'));
  }
}

class _FakeMapboxMapService implements MapboxMapService {
  @override
  Future<MapBounds?> visibleBounds() async => null;

  @override
  Future<void> showPinPhotos(Map<String, StyleImage> photos) async {}

  @override
  Future<void> showFocus(MapFocus? focus, {bool moveCamera = true}) async {}

  @override
  Future<void> showGuardLocation(GuardLocation? location) async {}
  @override
  Future<void> showGuardRadius(List<CommunityReport> reports) async {}
  @override
  Future<void> showReports(
    List<CommunityReport> reports, {
    bool recenter = false,
  }) async {}
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
}

class _FakeProfilePictureViewModel extends ProfilePictureViewModel {
  @override
  ProfilePictureState build() => const ProfilePictureState();
}
