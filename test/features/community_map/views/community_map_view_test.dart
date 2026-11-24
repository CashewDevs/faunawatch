import 'dart:async';

import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_location_service.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_notification_service.dart';
import 'package:faunawatch/features/fauna_guard/views/widgets/fauna_guard_intro_dialog.dart';
import '../../fauna_guard/guard_fakes.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_post_dialog.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_post_flip_transition.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import '../../feed/fake_feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:faunawatch/features/community_map/models/map_focus.dart';
import 'package:faunawatch/features/community_map/models/map_pin_filter.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_filter_sheet.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_guide_sheet.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_spot_sheet.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';
import 'package:faunawatch/features/public_profile/views/widgets/profile_preview_sheet.dart';
import '../../public_profile/fake_public_profile_service.dart';

void main() {
  Widget buildMap({
    ThemeData? theme,
    double textScale = 1,
    bool disableAnimations = false,
    String? userId,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        mapboxMapCanvasBuilderProvider.overrideWithValue(
          _FakeMapboxMapCanvasBuilder(),
        ),
        mapboxMapServiceProvider.overrideWithValue(_FakeMapboxMapService()),
        currentUserIdProvider.overrideWith((ref) => Stream.value(userId)),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: const CommunityMapView(),
      ),
    );
  }

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'FaunaGuard ${reducedMotion ? 'reduces motion' : 'flips its introduction'} and requires opt-in',
      (tester) async {
        final location = FakeGuardLocation();
        final notifications = FakeGuardNotifications();
        addTearDown(location.fixes.close);
        await tester.pumpWidget(
          buildMap(
            userId: 'guard-user',
            disableAnimations: reducedMotion,
            extraOverrides: [
              communityReportsServiceProvider.overrideWithValue(
                FakeGuardReports(),
              ),
              guardLocationServiceProvider.overrideWithValue(location),
              guardNotificationServiceProvider.overrideWithValue(notifications),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(location.requests, 0);
        await tester.tap(find.byTooltip('Turn on FaunaGuard'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final transition = tester.widget<FaunaGuardFlipTransition>(
          find.byType(FaunaGuardFlipTransition),
        );
        expect(
          transition.animation.value,
          reducedMotion ? 1 : inExclusiveRange(0, 1),
        );
        await tester.pumpAndSettle();
        expect(find.text('Meet FaunaGuard'), findsOneWidget);
        expect(find.textContaining('500 m'), findsOneWidget);
        expect(location.requests, 0);
        await tester.ensureVisible(find.text('Not now'));
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
        expect(location.requests, 0);
        await tester.tap(find.byTooltip('Turn on FaunaGuard'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Turn on FaunaGuard'));
        await tester.tap(find.text('Turn on FaunaGuard'));
        await tester.pumpAndSettle();
        expect(location.requests, 1);
        expect(find.byTooltip('Turn off FaunaGuard'), findsOneWidget);
        location.fixes.add(guardFix(900));
        await tester.pumpAndSettle();
        expect(find.text('FaunaGuard: getting closer'), findsOneWidget);
        expect(notifications.shown, hasLength(1));
        await tester.tap(find.byTooltip('Turn off FaunaGuard'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Turn on FaunaGuard'), findsOneWidget);
        expect(location.fixes.hasListener, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'FaunaGuard introduction fits a small dark screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildMap(theme: ThemeData.dark(), textScale: 1.8),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Turn on FaunaGuard'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Not now'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    },
  );

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'pin preview ${reducedMotion ? 'respects reduced motion' : 'flips open and closed'} and can reopen',
      (tester) async {
        await tester.pumpWidget(
          buildMap(
            disableAnimations: reducedMotion,
            extraOverrides: [
              communityReportsServiceProvider.overrideWithValue(
                const _FakeReports([
                  CommunityReport(
                    id: 'flip',
                    category: 'animal_in_need',
                    latitude: 10.12,
                    longitude: 123.12,
                    description: 'Bird near the trail.',
                  ),
                ]),
              ),
            ],
          ),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CommunityMapView)),
        );
        final vm = container.read(communityMapViewModelProvider.notifier);
        await vm.onStyleLoaded();
        vm.selectPost('flip');
        vm.selectPost('flip');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final transition = tester.widget<MapPostFlipTransition>(
          find.byType(MapPostFlipTransition),
        );
        if (reducedMotion) {
          expect(transition.animation.value, 1);
        } else {
          expect(transition.animation.status, AnimationStatus.forward);
          expect(transition.animation.value, inExclusiveRange(0, 1));
        }
        await tester.pumpAndSettle();
        expect(find.byType(MapPostDialog), findsOneWidget);
        expect(find.text('Bird near the trail.'), findsOneWidget);
        await tester.tap(find.byTooltip('Close post preview'));
        await tester.pump();
        if (!reducedMotion) {
          expect(
            tester
                .widget<MapPostFlipTransition>(
                  find.byType(MapPostFlipTransition),
                )
                .animation
                .status,
            AnimationStatus.reverse,
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(MapPostDialog), findsNothing);
        expect(
          container.read(communityMapViewModelProvider).selectedPostId,
          isNull,
        );
        vm.selectPost('flip');
        await tester.pumpAndSettle();
        expect(find.byType(MapPostDialog), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MapPostDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a report pin opens its post in the feed through see more', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildMap(
        theme: ThemeData.dark(useMaterial3: true),
        textScale: 1.5,
        extraOverrides: [
          communityReportsServiceProvider.overrideWithValue(
            _FakeReports(const [
              CommunityReport(
                id: 'r1',
                category: 'animal_in_need',
                latitude: 10.12,
                longitude: 123.12,
                description: 'Bird near the road.',
              ),
            ]),
          ),
          feedServiceProvider.overrideWithValue(
            FakeFeedService(posts: [testPost('r1', title: 'Bird')]),
          ),
        ],
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CommunityMapView)),
    );
    final vm = container.read(communityMapViewModelProvider.notifier);
    await vm.onStyleLoaded();
    vm.selectPost('r1');
    await tester.pumpAndSettle();
    expect(find.byType(MapPostDialog), findsOneWidget);
    expect(find.text('Approved wildlife report'), findsOneWidget);
    expect(find.text('Sample post'), findsNothing);
    expect(find.text('Bird near the road.'), findsOneWidget);

    await tester.ensureVisible(find.text('See more in feed'));
    await tester.tap(find.text('See more in feed'));
    await tester.pumpAndSettle();
    expect(container.read(shellViewModelProvider), ShellDestination.feed);
    expect(container.read(feedViewModelProvider).focusedPostId, 'r1');
    expect(find.text('See more in feed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a shared pin lists its posts with their posters, and a row opens its card',
    (tester) async {
      await tester.pumpWidget(
        buildMap(
          extraOverrides: [
            communityReportsServiceProvider.overrideWithValue(
              _FakeReports([
                CommunityReport(
                  id: 'older',
                  category: 'animal_in_need',
                  latitude: 10.12,
                  longitude: 123.12,
                  description: 'Owl on a fence.',
                  createdAt: DateTime.utc(2026, 11, 1),
                ),
                CommunityReport(
                  id: 'newer',
                  category: 'animal_in_need',
                  latitude: 10.12,
                  longitude: 123.12,
                  description: 'Bird near the road.',
                  createdAt: DateTime.utc(2026, 11, 20),
                ),
              ]),
            ),
            feedServiceProvider.overrideWithValue(
              FakeFeedService(
                posts: [
                  testPost('newer', authorId: 'u-ana', authorName: 'ana'),
                  testPost('older', authorId: 'u-ben', authorName: 'ben'),
                ],
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CommunityMapView)),
      );
      final vm = container.read(communityMapViewModelProvider.notifier);
      await vm.onStyleLoaded();
      vm.onPinTap('newer');
      await tester.pumpAndSettle();

      expect(find.byType(MapSpotSheet), findsOneWidget);
      expect(find.text('2 posts here'), findsOneWidget);
      expect(find.text('ana · Bird near the road.'), findsOneWidget);
      expect(find.text('ben · Owl on a fence.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('ana · Bird near the road.')).dy,
        lessThan(tester.getTopLeft(find.text('ben · Owl on a fence.')).dy),
      );

      await tester.tap(find.text('ben · Owl on a fence.'));
      await tester.pumpAndSettle();
      expect(find.byType(MapSpotSheet), findsNothing);
      expect(find.byType(MapPostDialog), findsOneWidget);
      expect(find.text('Owl on a fence.'), findsOneWidget);
      expect(find.text('ben'), findsOneWidget);
      expect(find.text('Community spotter'), findsNothing);
      expect(
        container.read(communityMapViewModelProvider).selectedSpot,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("a pin card's author opens the profile preview over the card", (
    tester,
  ) async {
    final public = FakePublicProfileService();
    await tester.pumpWidget(
      buildMap(
        userId: 'viewer',
        extraOverrides: [
          communityReportsServiceProvider.overrideWithValue(
            const _FakeReports([
              CommunityReport(
                id: 'r1',
                category: 'animal_in_need',
                latitude: 10.12,
                longitude: 123.12,
                description: 'Bird near the road.',
              ),
            ]),
          ),
          feedServiceProvider.overrideWithValue(
            FakeFeedService(
              posts: [testPost('r1', authorId: 'u-ana', authorName: 'ana')],
            ),
          ),
          publicProfileServiceProvider.overrideWithValue(public),
        ],
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CommunityMapView)),
    );
    final vm = container.read(communityMapViewModelProvider.notifier);
    await vm.onStyleLoaded();
    vm.selectPost('r1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('ana'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePreviewSheet), findsOneWidget);
    expect(find.byType(MapPostDialog), findsOneWidget);
    expect(public.profileRequests, ['u-ana']);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePreviewSheet), findsNothing);
    expect(find.byType(MapPostDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses compact controls with info beside the dimension toggle', (
    tester,
  ) async {
    await tester.pumpWidget(buildMap());
    await tester.pump();
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('Community map'), findsNothing);
    expect(find.text('How this map works'), findsNothing);
    final info = tester.getRect(find.byTooltip('About this map'));
    final mode = tester.getRect(find.byTooltip('Switch to 2D'));
    final refresh = tester.getRect(
      find.byTooltip('No approved reports yet. Refresh'),
    );
    expect(info.size, const Size(48, 48));
    expect(mode.size, info.size);
    expect(refresh.size, info.size);
    expect(info.right, lessThan(mode.left));
    expect(info.center.dy, mode.center.dy);
    expect(refresh.center.dy, mode.center.dy);
    expect(refresh.right, lessThan(info.left));
  });

  testWidgets('info opens the guide directly and can reopen after closing', (
    tester,
  ) async {
    await tester.pumpWidget(buildMap());
    await tester.pump();
    await tester.tap(find.byTooltip('About this map'));
    await tester.pumpAndSettle();
    expect(find.byType(MapGuideSheet), findsOneWidget);
    expect(find.text('Find reported encounters'), findsOneWidget);
    expect(
      find.textContaining(
        'A number on a pin means several posts share that spot; tap it to see them all.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('demo'), findsNothing);
    await tester.tap(find.byTooltip('Close map guide'));
    await tester.pumpAndSettle();
    expect(find.byType(MapGuideSheet), findsNothing);
    await tester.tap(find.byTooltip('About this map'));
    await tester.pumpAndSettle();
    expect(find.byType(MapGuideSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh shows loading, prevents duplicate taps and keeps its compact size',
    (tester) async {
      final reports = _ControlledReports();
      await tester.pumpWidget(
        buildMap(
          extraOverrides: [
            communityReportsServiceProvider.overrideWithValue(reports),
          ],
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CommunityMapView)),
      );
      await container
          .read(communityMapViewModelProvider.notifier)
          .onStyleLoaded();
      await tester.pump();
      expect(reports.loads, 1);
      reports.pending = Completer<List<CommunityReport>>();
      await tester.tap(find.byTooltip('No approved reports yet. Refresh'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final loading = find.byTooltip('Loading reports');
      expect(tester.getSize(loading), const Size(48, 48));
      final button = tester.widget<IconButton>(
        find.ancestor(of: loading, matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNull);
      await tester.tap(loading);
      expect(reports.loads, 2);
      reports.pending!.complete([]);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byTooltip('No approved reports yet. Refresh'),
        findsOneWidget,
      );
      expect(container.read(communityMapViewModelProvider).reports, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh exposes failures and retries without a status banner', (
    tester,
  ) async {
    final reports = _ControlledReports()..fail = true;
    await tester.pumpWidget(
      buildMap(
        extraOverrides: [
          communityReportsServiceProvider.overrideWithValue(reports),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CommunityMapView)),
    );
    await container
        .read(communityMapViewModelProvider.notifier)
        .onStyleLoaded();
    await tester.pump();
    expect(
      find.byTooltip('Could not load reports. Tap to retry'),
      findsOneWidget,
    );
    reports.fail = false;
    reports.items = const [
      CommunityReport(
        id: 'r1',
        category: 'animal_in_need',
        latitude: 10.12,
        longitude: 123.12,
        description: 'Bird',
      ),
    ];
    await tester.tap(find.byTooltip('Could not load reports. Tap to retry'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh reports (1 approved)'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    expect(
      container.read(communityMapViewModelProvider).reports.single.id,
      'r1',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('controls and guide fit a small dark screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildMap(theme: ThemeData.dark(useMaterial3: true), textScale: 1.5),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('About this map'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Try it now:'));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Close map guide'));
    await tester.tap(find.byTooltip('Close map guide'));
    await tester.pumpAndSettle();
    expect(find.byType(MapGuideSheet), findsNothing);
    await tester.tap(find.byTooltip('Switch to 2D'));
    await tester.pump();
    expect(find.byTooltip('Switch to 3D'), findsOneWidget);
    expect(find.byTooltip('About this map'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the initial viewport when changing map dimension', (
    tester,
  ) async {
    final canvasBuilder = _FakeMapboxMapCanvasBuilder();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapboxMapCanvasBuilderProvider.overrideWithValue(canvasBuilder),
          mapboxMapServiceProvider.overrideWithValue(_FakeMapboxMapService()),
          currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: CommunityMapView()),
      ),
    );
    await tester.pump();

    final viewportBeforeToggle = canvasBuilder.viewports.last;
    final viewport = viewportBeforeToggle as CameraViewportState;
    expect(viewport.center!.coordinates.lng, 122);
    expect(viewport.center!.coordinates.lat, 12);
    expect(viewport.pitch, 55);
    expect(find.byTooltip('Switch to 2D'), findsOneWidget);
    await tester.tap(find.text('3D'));
    await tester.pump();

    expect(find.text('2D'), findsOneWidget);
    expect(canvasBuilder.viewports.last, same(viewportBeforeToggle));
  });

  group('pin filter', () {
    const reports = [
      CommunityReport(
        id: 'cobra',
        category: 'potentially_dangerous_animal',
        latitude: 10.12,
        longitude: 123.12,
        description: 'Snake',
        species: 'Philippine cobra',
      ),
      CommunityReport(
        id: 'eagle',
        category: 'animal_in_need',
        latitude: 11.12,
        longitude: 123.12,
        description: 'Bird',
        species: 'Philippine eagle',
      ),
    ];

    Future<ProviderContainer> openMap(
      WidgetTester tester, {
      ThemeData? theme,
      double textScale = 1,
    }) async {
      await tester.pumpWidget(
        buildMap(
          theme: theme,
          textScale: textScale,
          extraOverrides: [
            communityReportsServiceProvider.overrideWithValue(
              const _FakeReports(reports),
            ),
          ],
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CommunityMapView)),
      );
      await container
          .read(communityMapViewModelProvider.notifier)
          .onStyleLoaded();
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('the Filter pill sits left of the controls and shows ticks', (
      tester,
    ) async {
      final container = await openMap(tester);
      final pill = tester.getRect(find.byTooltip('Filter pins'));
      final refresh = tester.getRect(
        find.byTooltip('Refresh reports (2 approved)'),
      );
      expect(pill.height, 48);
      expect(pill.center.dy, refresh.center.dy);
      expect(pill.right, lessThan(refresh.left));
      expect(find.text('Filter'), findsOneWidget);

      await tester.tap(find.byTooltip('Filter pins'));
      await tester.pumpAndSettle();
      expect(find.byType(MapFilterSheet), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Animal in need'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 1 post'));
      await tester.pumpAndSettle();

      expect(find.byType(MapFilterSheet), findsNothing);
      expect(find.text('Filter · 1'), findsOneWidget);
      expect(find.byTooltip('Filter pins (1 selected)'), findsOneWidget);
      expect(
        find.byTooltip('Refresh reports (showing 1 of 2)'),
        findsOneWidget,
      );
      expect(
        container
            .read(communityMapViewModelProvider)
            .visibleReports
            .map((r) => r.id),
        ['eagle'],
      );

      // Reopening starts from the applied ticks.
      await tester.tap(find.byTooltip('Filter pins (1 selected)'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Animal in need'),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a filter hiding every pin offers to clear it', (tester) async {
      final container = await openMap(tester);
      expect(find.text('No pins match this filter.'), findsNothing);
      await container
          .read(communityMapViewModelProvider.notifier)
          .setFilter(
            const MapPinFilter(
              categories: {ReportCategory.otherWildlifeIncident},
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('No pins match this filter.'), findsOneWidget);

      await tester.tap(find.text('Clear filter'));
      await tester.pumpAndSettle();
      expect(find.text('No pins match this filter.'), findsNothing);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.byTooltip('Refresh reports (2 approved)'), findsOneWidget);
    });

    testWidgets('the pill and sheet fit a small dark screen with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openMap(
        tester,
        theme: ThemeData.dark(useMaterial3: true),
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Filter pins'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Philippine eagle'),
        80,
        scrollable: find
            .descendant(
              of: find.byType(MapFilterSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Show 2 posts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the guide explains the filter', (tester) async {
    await tester.pumpWidget(buildMap());
    await tester.pump();
    await tester.tap(find.byTooltip('About this map'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Filter the pins'));
    expect(find.textContaining('Unknown species'), findsOneWidget);
  });
}

class _FakeMapboxMapCanvasBuilder implements MapboxMapCanvasBuilder {
  final List<ViewportState> viewports = [];

  @override
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
    OnMapIdleListener? onMapIdle,
  }) {
    viewports.add(viewport);
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
  Future<void> showReports(
    List<CommunityReport> reports, {
    bool recenter = false,
  }) async {}
}

class _FakeReports implements CommunityReportsService {
  const _FakeReports(this.reports);
  final List<CommunityReport> reports;

  @override
  Future<List<CommunityReport>> load() async => reports;
}

class _ControlledReports implements CommunityReportsService {
  int loads = 0;
  bool fail = false;
  List<CommunityReport> items = [];
  Completer<List<CommunityReport>>? pending;

  @override
  Future<List<CommunityReport>> load() async {
    loads++;
    if (fail) throw StateError('offline');
    return pending?.future ?? items;
  }
}
