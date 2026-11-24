import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_location_service.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_notification_service.dart';
import 'package:faunawatch/features/fauna_guard/viewmodels/fauna_guard_viewmodel.dart';
import '../../fauna_guard/guard_fakes.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import '../../feed/fake_feed_service.dart';
import '../../create_post/location_picker_fakes.dart' show FakePickerPlatform;
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/models/community_map_state.dart';
import 'package:faunawatch/features/community_map/models/map_focus.dart';
import 'package:faunawatch/features/community_map/models/map_pin_filter.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/community_map/services/map_pin_photo_service.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';

void main() {
  late ProviderContainer container;
  late _FakeMapboxMapService mapboxMapService;
  late _Reports reports;
  late FakeFeedService feed;

  setUp(() {
    mapboxMapService = _FakeMapboxMapService();
    reports = _Reports();
    feed = FakeFeedService(posts: [testPost('approved', title: 'Bird')]);
    container = ProviderContainer(
      overrides: [
        mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
        communityReportsServiceProvider.overrideWithValue(reports),
        currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
        feedServiceProvider.overrideWithValue(feed),
      ],
    );
  });

  tearDown(() => container.dispose());

  test(
    'FaunaGuard waits for style, restores its fix after reload, and clears on stop',
    () async {
      final gps = FakeGuardLocation();
      final guardContainer = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('map-user')),
          mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
          communityReportsServiceProvider.overrideWithValue(reports),
          guardLocationServiceProvider.overrideWithValue(gps),
          guardNotificationServiceProvider.overrideWithValue(
            FakeGuardNotifications(),
          ),
        ],
      );
      addTearDown(guardContainer.dispose);
      addTearDown(gps.fixes.close);
      final map = guardContainer.read(communityMapViewModelProvider.notifier);
      await pumpEventQueue();
      final guard = guardContainer.read(faunaGuardViewModelProvider.notifier);
      await guard.enable();
      final first = guardFix(1500);
      gps.fixes.add(first);
      await pumpEventQueue();
      expect(mapboxMapService.locations, isEmpty);
      await map.onStyleLoaded();
      expect(mapboxMapService.locations.last, first);
      expect(mapboxMapService.reportCalls.last.recenter, isFalse);
      final moved = guardFix(1600);
      gps.fixes.add(moved);
      await pumpEventQueue();
      expect(mapboxMapService.locations.last, moved);
      await map.onStyleLoaded();
      expect(mapboxMapService.locations.last, moved);
      guard.disable();
      await pumpEventQueue();
      expect(mapboxMapService.locations.last, isNull);
    },
  );

  test('FaunaGuard rings show only while FaunaGuard is on', () async {
    final gps = FakeGuardLocation();
    final guardContainer = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value('map-user')),
        mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
        communityReportsServiceProvider.overrideWithValue(reports),
        guardLocationServiceProvider.overrideWithValue(gps),
        guardNotificationServiceProvider.overrideWithValue(
          FakeGuardNotifications(),
        ),
      ],
    );
    addTearDown(guardContainer.dispose);
    addTearDown(gps.fixes.close);
    final map = guardContainer.read(communityMapViewModelProvider.notifier);
    await pumpEventQueue();
    await map.onStyleLoaded();
    expect(mapboxMapService.radiusCalls.last, isEmpty);

    final guard = guardContainer.read(faunaGuardViewModelProvider.notifier);
    await guard.enable();
    await pumpEventQueue();
    expect(mapboxMapService.radiusCalls.last.map((r) => r.id), ['approved']);

    reports.items = [];
    await map.refreshReports();
    expect(mapboxMapService.radiusCalls.last, isEmpty);

    reports.items = [_report];
    await map.refreshReports();
    guard.disable();
    await pumpEventQueue();
    expect(mapboxMapService.radiusCalls.last, isEmpty);
  });

  test(
    'loads approved reports, opens a report, and can retry a failed refresh',
    () async {
      final vm = container.read(communityMapViewModelProvider.notifier);
      await vm.onStyleLoaded();
      expect(
        container.read(communityMapViewModelProvider).reports.single.id,
        'approved',
      );
      vm.selectPost('approved');
      expect(vm.selectedPreview!.author, 'Community spotter');
      vm.seeMore();
      await pumpEventQueue();
      expect(container.read(feedViewModelProvider).focusedPostId, 'approved');
      expect(container.read(shellViewModelProvider), ShellDestination.feed);
      reports.fail = true;
      await vm.refreshReports();
      expect(
        container.read(communityMapViewModelProvider).reportsHaveError,
        isTrue,
      );
      expect(
        container.read(communityMapViewModelProvider).reports,
        hasLength(1),
      );
      reports.fail = false;
      await vm.refreshReports();
      expect(
        container.read(communityMapViewModelProvider).reportsHaveError,
        isFalse,
      );
    },
  );

  test('selects only loaded reports and can dismiss', () async {
    final vm = container.read(communityMapViewModelProvider.notifier);
    vm.selectPost('unknown');
    vm.selectPost('sample-cebu-incident');
    expect(
      container.read(communityMapViewModelProvider).selectedPostId,
      isNull,
    );
    await vm.onStyleLoaded();
    vm.selectPost('approved');
    expect(vm.selectedPreview!.id, 'approved');
    vm.dismissPost();
    expect(vm.selectedPreview, isNull);
  });

  test('see more does nothing without a valid selection', () {
    final vm = container.read(communityMapViewModelProvider.notifier);
    container
        .read(shellViewModelProvider.notifier)
        .selectDestination(ShellDestination.chats);
    vm.seeMore();
    vm.selectPost('sample-cebu-incident');
    vm.seeMore();
    expect(container.read(shellViewModelProvider), ShellDestination.chats);
    expect(container.read(feedViewModelProvider).focusedPostId, isNull);
  });

  test('starts in 3D mode using the light appearance', () {
    final state = container.read(communityMapViewModelProvider);

    expect(state.is3dEnabled, isTrue);
    expect(state.brightness, Brightness.light);
  });

  test('waits for style and frames the first nonempty result only', () async {
    final vm = container.read(communityMapViewModelProvider.notifier);
    await vm.refreshReports();
    expect(mapboxMapService.reportCalls, isEmpty);
    reports.items = [];
    await vm.onStyleLoaded();
    expect(mapboxMapService.reportCalls.single.recenter, isFalse);
    reports.items = [_report];
    await vm.refreshReports();
    expect(mapboxMapService.reportCalls.last.recenter, isTrue);
    await vm.refreshReports();
    expect(mapboxMapService.reportCalls.last.recenter, isFalse);
    await vm.onStyleLoaded();
    expect(mapboxMapService.reportCalls.last.recenter, isFalse);
  });

  test('failed draw can retry and still frame the first reports', () async {
    final vm = container.read(communityMapViewModelProvider.notifier);
    mapboxMapService.failReports = true;
    await vm.onStyleLoaded();
    expect(
      container.read(communityMapViewModelProvider).reportsHaveError,
      isTrue,
    );
    mapboxMapService.failReports = false;
    await vm.refreshReports();
    expect(mapboxMapService.reportCalls.last.recenter, isTrue);
    expect(
      container.read(communityMapViewModelProvider).reportsHaveError,
      isFalse,
    );
  });

  test(
    'refresh removes a selection when the report is no longer approved',
    () async {
      final vm = container.read(communityMapViewModelProvider.notifier);
      await vm.onStyleLoaded();
      vm.selectPost('approved');
      reports.items = [];
      await vm.refreshReports();
      expect(
        container.read(communityMapViewModelProvider).selectedPostId,
        isNull,
      );
      expect(vm.selectedPreview, isNull);
    },
  );

  test('applies the active theme after the Mapbox style has loaded', () async {
    final viewModel = container.read(communityMapViewModelProvider.notifier);

    await viewModel.setBrightness(Brightness.dark);
    expect(mapboxMapService.appearanceCalls, isEmpty);

    await viewModel.onStyleLoaded();

    expect(
      mapboxMapService.appearanceCalls,
      equals([(brightness: Brightness.dark, is3dEnabled: true)]),
    );
  });

  test('switches to 2D and reapplies the configured appearance', () async {
    final viewModel = container.read(communityMapViewModelProvider.notifier);
    await viewModel.onStyleLoaded();

    await viewModel.toggle3d();

    expect(container.read(communityMapViewModelProvider).is3dEnabled, isFalse);
    expect(
      mapboxMapService.appearanceCalls.last,
      equals((brightness: Brightness.light, is3dEnabled: false)),
    );
  });

  group('photo pins', () {
    late _PinPhotos photos;
    late ProviderContainer pins;
    final user = StateProvider<String?>((ref) => 'me');

    CommunityReport photoReport(
      String id, {
      double lat = 10,
      double lng = 120,
    }) => CommunityReport(
      id: id,
      category: 'animal_in_need',
      latitude: lat,
      longitude: lng,
      description: id,
      photoPath: '$id/photo.webp',
    );

    Future<CommunityMapViewModel> open(
      List<CommunityReport> items, {
      Set<String> failing = const {},
      Completer<void>? gate,
    }) async {
      photos = _PinPhotos()
        ..failing.addAll(failing)
        ..gate = gate;
      reports.items = items;
      pins = ProviderContainer(
        overrides: [
          mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
          communityReportsServiceProvider.overrideWithValue(reports),
          currentUserIdProvider.overrideWith(
            (ref) => Stream.value(ref.watch(user)),
          ),
          feedServiceProvider.overrideWithValue(feed),
          mapPinPhotoServiceProvider.overrideWithValue(photos),
        ],
      );
      addTearDown(pins.dispose);
      await pins.read(currentUserIdProvider.future);
      final map = pins.read(communityMapViewModelProvider.notifier);
      await map.onStyleLoaded();
      await pumpEventQueue();
      return map;
    }

    Set<String> shown() => {
      for (final call in mapboxMapService.photoCalls) ...call.keys,
    };

    test('loads only on-screen pins with a photo, once each', () async {
      mapboxMapService.bounds = (south: 9, west: 119, north: 11, east: 121);
      final map = await open([
        photoReport('near'),
        photoReport('far', lat: 40, lng: 140),
        const CommunityReport(
          id: 'no-photo',
          category: 'animal_in_need',
          latitude: 10,
          longitude: 120,
          description: 'x',
        ),
      ]);
      expect(photos.requests, ['near/photo.webp']);
      expect(shown(), {'near'});

      await map.onMapIdle();
      expect(photos.requests, hasLength(1));

      mapboxMapService.bounds = (south: 39, west: 139, north: 41, east: 141);
      await map.onMapIdle();
      expect(photos.requests, ['near/photo.webp', 'far/photo.webp']);
      expect(shown(), {'near', 'far'});
    });

    test('loads at most four at a time', () async {
      final gate = Completer<void>();
      // Separate spots: reports on one spot share the newest one's photo.
      await open([
        for (var i = 0; i < 6; i++) photoReport('r$i', lat: 10 + i / 10),
      ], gate: gate);
      expect(photos.requests, hasLength(CommunityMapViewModel.photosAtOnce));
      gate.complete();
      await pumpEventQueue();
      expect(photos.requests, hasLength(6));
      expect(shown(), hasLength(6));
    });

    test('a failed photo keeps the logo and retries after a refresh', () async {
      final map = await open(
        [photoReport('broken')],
        failing: {'broken/photo.webp'},
      );
      expect(photos.requests, hasLength(1));
      expect(shown(), isEmpty);
      await map.onMapIdle();
      expect(photos.requests, hasLength(1));

      photos.failing.clear();
      await map.refreshReports();
      await pumpEventQueue();
      expect(photos.requests, hasLength(2));
      expect(shown(), {'broken'});
    });

    test('loaded photos are put back after the reports refresh', () async {
      final map = await open([photoReport('kept')]);
      mapboxMapService.photoCalls.clear();
      await map.refreshReports();
      await pumpEventQueue();
      expect(mapboxMapService.photoCalls.first.keys, ['kept']);
      expect(photos.requests, hasLength(1));
    });

    test('an account change forgets photos and drops late ones', () async {
      final map = await open([photoReport('a')]);
      expect(photos.requests, hasLength(1));

      pins.read(user.notifier).state = 'someone-else';
      await pumpEventQueue();
      await map.onMapIdle();
      // Forgotten, so it is loaded again for the new account.
      expect(photos.requests, hasLength(2));

      photos.gate = Completer<void>();
      reports.items = [photoReport('a'), photoReport('b')];
      final refreshing = map.refreshReports();
      await pumpEventQueue();
      mapboxMapService.photoCalls.clear();
      pins.read(user.notifier).state = 'third-user';
      await pumpEventQueue();
      photos.gate!.complete();
      await refreshing;
      await pumpEventQueue();
      expect(shown(), isNot(contains('b')));
    });
  });

  group('focusOn', () {
    const public = MapFocus(
      postId: 'approved',
      latitude: 10.12,
      longitude: 123.12,
      isPublic: true,
    );
    const private = MapFocus(
      postId: 'mine',
      latitude: 16.46,
      longitude: 120.99,
      isPublic: false,
    );

    CommunityMapState state() => container.read(communityMapViewModelProvider);
    CommunityMapViewModel vm() =>
        container.read(communityMapViewModelProvider.notifier);

    test('opens the Map tab and waits for the map to load', () async {
      container
          .read(shellViewModelProvider.notifier)
          .selectDestination(ShellDestination.profile);
      await vm().focusOn(public);
      expect(container.read(shellViewModelProvider), ShellDestination.map);
      expect(mapboxMapService.focusCalls, isEmpty);

      await vm().onStyleLoaded();
      expect(mapboxMapService.focusCalls.single.focus, public);
      expect(mapboxMapService.focusCalls.single.moveCamera, isTrue);
      // The requested spot wins over fitting every report into view.
      expect(mapboxMapService.reportCalls.single.recenter, isFalse);
      expect(state().privateFocus, isNull);
    });

    test('a public post missing from the map refreshes the pins', () async {
      await vm().onStyleLoaded();
      expect(mapboxMapService.reportCalls, hasLength(1));
      await vm().focusOn(public);
      expect(mapboxMapService.reportCalls, hasLength(1));
      const newer = MapFocus(
        postId: 'just-approved',
        latitude: 1,
        longitude: 2,
        isPublic: true,
      );
      await vm().focusOn(newer);
      expect(mapboxMapService.reportCalls, hasLength(2));
      expect(mapboxMapService.focusCalls.last.focus, newer);
    });

    test('a private post shows the owner marker until dismissed', () async {
      await vm().onStyleLoaded();
      vm().selectPost('approved');
      await vm().focusOn(private);
      expect(state().privateFocus, private);
      expect(state().selectedPostId, isNull);
      expect(mapboxMapService.focusCalls.last.focus, private);

      // A style reload redraws the marker without moving the camera.
      await vm().onStyleLoaded();
      expect(mapboxMapService.focusCalls.last.focus, private);
      expect(mapboxMapService.focusCalls.last.moveCamera, isFalse);

      await vm().dismissPrivateFocus();
      expect(state().privateFocus, isNull);
      expect(mapboxMapService.focusCalls.last.focus, isNull);

      await vm().focusOn(private);
      await vm().focusOn(public);
      expect(state().privateFocus, isNull);
    });

    test('an account change removes the owner marker', () async {
      final user = StateProvider<String?>((ref) => 'owner');
      final accounts = ProviderContainer(
        overrides: [
          mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
          communityReportsServiceProvider.overrideWithValue(reports),
          currentUserIdProvider.overrideWith(
            (ref) => Stream.value(ref.watch(user)),
          ),
          feedServiceProvider.overrideWithValue(feed),
        ],
      );
      addTearDown(accounts.dispose);
      await accounts.read(currentUserIdProvider.future);
      final map = accounts.read(communityMapViewModelProvider.notifier);
      await map.onStyleLoaded();
      await map.focusOn(private);
      expect(
        accounts.read(communityMapViewModelProvider).privateFocus,
        private,
      );

      accounts.read(user.notifier).state = 'someone-else';
      await pumpEventQueue();
      expect(accounts.read(communityMapViewModelProvider).privateFocus, isNull);
      expect(mapboxMapService.focusCalls.last.focus, isNull);
    });

    group('focusOnPost', () {
      late _OwnLocations locations;
      late ProviderContainer owner;
      final user = StateProvider<String?>((ref) => 'me');

      Future<CommunityMapViewModel> open() async {
        locations = _OwnLocations();
        owner = ProviderContainer(
          overrides: [
            mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
            communityReportsServiceProvider.overrideWithValue(reports),
            currentUserIdProvider.overrideWith(
              (ref) => Stream.value(ref.watch(user)),
            ),
            feedServiceProvider.overrideWithValue(feed),
            reportDetailServiceProvider.overrideWithValue(locations),
          ],
        );
        addTearDown(owner.dispose);
        await owner.read(currentUserIdProvider.future);
        final map = owner.read(communityMapViewModelProvider.notifier);
        await map.onStyleLoaded();
        return map;
      }

      final ownPost = testPost(
        'mine',
        authorId: 'me',
        latitude: 16.46,
        longitude: 120.99,
      );

      test(
        'own posts open at their exact spot with the owner marker',
        () async {
          final map = await open();
          locations.points['mine'] = (
            latitude: 16.456789,
            longitude: 120.987654,
          );
          await map.focusOnPost(ownPost, isPublic: true);
          final focus = owner.read(communityMapViewModelProvider).privateFocus!;
          expect(focus.isExact, isTrue);
          expect(focus.isPublic, isTrue);
          expect(focus.latitude, 16.456789);
          expect(mapboxMapService.focusCalls.last.focus, focus);
          expect(owner.read(shellViewModelProvider), ShellDestination.map);
          expect(locations.requests, ['mine']);
        },
      );

      test("other people's posts use the rounded point, no lookup", () async {
        final map = await open();
        await map.focusOnPost(
          testPost('theirs', latitude: 10.12, longitude: 123.12),
          isPublic: true,
        );
        expect(locations.requests, isEmpty);
        expect(owner.read(communityMapViewModelProvider).privateFocus, isNull);
        final focus = mapboxMapService.focusCalls.last.focus!;
        expect(focus.isExact, isFalse);
        expect(focus.latitude, 10.12);
      });

      test('a failed lookup falls back to the rounded point', () async {
        final map = await open();
        locations.fail = true;
        await map.focusOnPost(ownPost, isPublic: false);
        final focus = owner.read(communityMapViewModelProvider).privateFocus!;
        expect(focus.isExact, isFalse);
        expect(focus.latitude, 16.46);
      });

      test('an account change during the lookup shows nothing', () async {
        final map = await open();
        locations.points['mine'] = (latitude: 16.456789, longitude: 120.987654);
        locations.gate = Completer<void>();
        final opening = map.focusOnPost(ownPost, isPublic: false);
        owner.read(user.notifier).state = 'someone-else';
        await pumpEventQueue();
        locations.gate!.complete();
        await opening;
        expect(owner.read(communityMapViewModelProvider).privateFocus, isNull);
        expect(
          mapboxMapService.focusCalls.where((call) => call.focus != null),
          isEmpty,
        );
      });
    });

    test('MapFocus.fromPost needs a location', () {
      expect(
        MapFocus.fromPost(testPost('no-location'), isPublic: true),
        isNull,
      );
    });
  });

  group('shared pins, reloading and posters', () {
    late ProviderContainer shared;
    late DateTime now;

    CommunityReport at(String id, double lat, {DateTime? createdAt}) =>
        CommunityReport(
          id: id,
          category: 'animal_in_need',
          latitude: lat,
          longitude: 123.12,
          description: id,
          createdAt: createdAt,
        );

    setUp(() {
      now = DateTime(2026, 11, 22, 9);
      shared = ProviderContainer(
        overrides: [
          mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
          communityReportsServiceProvider.overrideWithValue(reports),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          feedServiceProvider.overrideWithValue(feed),
          communityMapClockProvider.overrideWithValue(() => now),
        ],
      );
    });

    tearDown(() => shared.dispose());

    test(
      'a pin with one post opens its card; a shared pin lists its posts, newest first',
      () async {
        reports.items = [
          at('old', 10.12, createdAt: DateTime(2026, 11, 1)),
          at('alone', 11.5),
          at('new', 10.12, createdAt: DateTime(2026, 11, 20)),
        ];
        final map = shared.read(communityMapViewModelProvider.notifier);
        await map.onStyleLoaded();
        CommunityMapState state() => shared.read(communityMapViewModelProvider);

        map.onPinTap('alone');
        expect(state().selectedPostId, 'alone');
        expect(state().selectedSpot, isNull);
        map.dismissPost();

        map.onPinTap('new');
        expect(state().selectedPostId, isNull);
        expect(state().selectedSpot!.reports.map((r) => r.id), ['new', 'old']);

        // Picking from the list closes it and opens that post's card.
        map.dismissSpot();
        map.selectPost('old');
        expect(state().selectedSpot, isNull);
        expect(state().selectedPostId, 'old');

        map.dismissPost();
        map.onPinTap('gone');
        expect(state().selectedPostId, isNull);
        expect(state().selectedSpot, isNull);
      },
    );

    test(
      'opening the Map tab reloads the posts unless they loaded in the last 30 seconds',
      () async {
        final map = shared.read(communityMapViewModelProvider.notifier);
        final shell = shared.read(shellViewModelProvider.notifier);
        // Before the map has loaded, the first load comes from the style.
        shell.goTo(ShellDestination.map);
        await pumpEventQueue();
        expect(reports.loads, 0);
        await map.onStyleLoaded();
        expect(reports.loads, 1);

        shell.goTo(ShellDestination.feed);
        now = now.add(const Duration(seconds: 29));
        shell.goTo(ShellDestination.map);
        await pumpEventQueue();
        expect(reports.loads, 1);

        shell.goTo(ShellDestination.feed);
        now = now.add(const Duration(seconds: 2));
        reports.items = [_report, at('approved-later', 12)];
        shell.goTo(ShellDestination.map);
        await pumpEventQueue();
        expect(reports.loads, 2);
        expect(
          shared.read(communityMapViewModelProvider).reports.map((r) => r.id),
          ['approved', 'approved-later'],
        );
      },
    );

    test(
      "the poster's name opens the Profile tab for your own posts and a public profile for others",
      () async {
        final map = shared.read(communityMapViewModelProvider.notifier);
        await shared.read(currentUserIdProvider.future);
        final opened = <String>[];

        map.openAuthor('someone', opened.add);
        expect(opened, ['someone']);
        expect(shared.read(shellViewModelProvider), ShellDestination.feed);

        map.openAuthor('me', opened.add);
        map.openAuthor('', opened.add);
        expect(opened, ['someone']);
        expect(shared.read(shellViewModelProvider), ShellDestination.profile);
      },
    );
  });

  group('pin filter', () {
    const inNeed = ReportCategory.animalInNeed;
    const dangerous = ReportCategory.potentiallyDangerousAnimal;

    CommunityReport post(
      String id,
      ReportCategory category, {
      String? species,
      double lat = 10.12,
      DateTime? createdAt,
      bool withPhoto = false,
    }) => CommunityReport(
      id: id,
      category: category.value,
      latitude: lat,
      longitude: 123.12,
      description: id,
      species: species,
      createdAt: createdAt,
      photoPath: withPhoto ? '$id/photo.webp' : null,
    );

    final cobra = post(
      'cobra',
      dangerous,
      species: 'Philippine cobra',
      lat: 11,
    );
    final eagle = post('eagle', inNeed, species: 'Philippine eagle', lat: 12);
    final unknown = post('unknown', inNeed, lat: 13);
    const all = ['cobra', 'eagle', 'unknown'];

    CommunityMapState state() => container.read(communityMapViewModelProvider);
    CommunityMapViewModel vm() =>
        container.read(communityMapViewModelProvider.notifier);
    List<String> drawn() =>
        mapboxMapService.reportCalls.last.reports.map((r) => r.id).toList();

    setUp(() => reports.items = [cobra, eagle, unknown]);

    test(
      'draws only the matching pins without moving the camera, and clears',
      () async {
        await vm().onStyleLoaded();
        expect(drawn(), all);

        await vm().setFilter(const MapPinFilter(categories: {inNeed}));
        expect(drawn(), ['eagle', 'unknown']);
        expect(mapboxMapService.reportCalls.last.recenter, isFalse);
        expect(state().visibleReports.map((r) => r.id), ['eagle', 'unknown']);
        expect(state().reports, hasLength(3));

        // The same filter again does not redraw.
        final draws = mapboxMapService.reportCalls.length;
        await vm().setFilter(const MapPinFilter(categories: {inNeed}));
        expect(mapboxMapService.reportCalls, hasLength(draws));

        await vm().clearFilter();
        expect(state().filter.isActive, isFalse);
        expect(drawn(), all);
      },
    );

    test('species ticks outside the ticked categories are dropped', () async {
      await vm().onStyleLoaded();
      await vm().setFilter(
        const MapPinFilter(
          categories: {inNeed},
          species: {'philippine cobra', 'philippine eagle'},
        ),
      );
      expect(
        state().filter,
        const MapPinFilter(categories: {inNeed}, species: {'philippine eagle'}),
      );
      expect(drawn(), ['eagle']);
    });

    test(
      'a refresh keeps the filter and drops species whose last post is gone',
      () async {
        await vm().onStyleLoaded();
        await vm().setFilter(
          const MapPinFilter(species: {'philippine cobra', 'philippine eagle'}),
        );
        expect(drawn(), ['cobra', 'eagle']);

        reports.items = [eagle, unknown];
        await vm().refreshReports();
        expect(
          state().filter,
          const MapPinFilter(species: {'philippine eagle'}),
        );
        expect(drawn(), ['eagle']);
      },
    );

    test('a filter picked while the pins are drawn is drawn next', () async {
      await vm().onStyleLoaded();
      final gate = mapboxMapService.drawGate = Completer<void>();
      final refreshing = vm().refreshReports();
      await pumpEventQueue();
      expect(drawn(), all);

      await vm().setFilter(const MapPinFilter(categories: {dangerous}));
      // Waits for the refresh instead of drawing at the same time.
      expect(drawn(), all);
      mapboxMapService.drawGate = null;
      gate.complete();
      await refreshing;
      await pumpEventQueue();
      expect(drawn(), ['cobra']);
      expect(state().filter.categories, {dangerous});
    });

    test('tapping a pin only counts the posts it shows', () async {
      reports.items = [post('a', inNeed), post('b', dangerous)];
      await vm().onStyleLoaded();
      vm().onPinTap('a');
      expect(state().selectedSpot?.count, 2);
      vm().dismissSpot();

      await vm().setFilter(const MapPinFilter(categories: {inNeed}));
      vm().onPinTap('a');
      expect(state().selectedSpot, isNull);
      expect(state().selectedPostId, 'a');
      vm().dismissPost();
      // A hidden post's pin cannot be tapped.
      vm().onPinTap('b');
      expect(state().selectedPostId, isNull);
    });

    test('a shared pin loads the photo of the post it now shows', () async {
      final photos = _PinPhotos();
      reports.items = [
        post(
          'new',
          dangerous,
          createdAt: DateTime.utc(2026, 11, 20),
          withPhoto: true,
        ),
        post(
          'old',
          inNeed,
          createdAt: DateTime.utc(2026, 11, 1),
          withPhoto: true,
        ),
      ];
      final withPhotos = ProviderContainer(
        overrides: [
          mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
          communityReportsServiceProvider.overrideWithValue(reports),
          currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
          feedServiceProvider.overrideWithValue(feed),
          mapPinPhotoServiceProvider.overrideWithValue(photos),
        ],
      );
      addTearDown(withPhotos.dispose);
      final map = withPhotos.read(communityMapViewModelProvider.notifier);
      await map.onStyleLoaded();
      await pumpEventQueue();
      expect(photos.requests, ['new/photo.webp']);

      await map.setFilter(const MapPinFilter(categories: {inNeed}));
      await pumpEventQueue();
      expect(photos.requests, ['new/photo.webp', 'old/photo.webp']);
    });

    test('FaunaGuard rings keep every post', () async {
      final gps = FakeGuardLocation();
      final guarded = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('map-user')),
          mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
          communityReportsServiceProvider.overrideWithValue(reports),
          guardLocationServiceProvider.overrideWithValue(gps),
          guardNotificationServiceProvider.overrideWithValue(
            FakeGuardNotifications(),
          ),
        ],
      );
      addTearDown(guarded.dispose);
      addTearDown(gps.fixes.close);
      final map = guarded.read(communityMapViewModelProvider.notifier);
      await pumpEventQueue();
      await map.onStyleLoaded();
      await guarded.read(faunaGuardViewModelProvider.notifier).enable();
      await pumpEventQueue();

      await map.setFilter(const MapPinFilter(categories: {inNeed}));
      await map.refreshReports();
      expect(drawn(), ['eagle', 'unknown']);
      expect(mapboxMapService.radiusCalls.last.map((r) => r.id), all);
    });

    test("opening a hidden post's location clears the filter", () async {
      await vm().onStyleLoaded();
      await vm().setFilter(const MapPinFilter(categories: {dangerous}));

      // A post the filter shows keeps it.
      const shown = MapFocus(
        postId: 'cobra',
        latitude: 11,
        longitude: 123.12,
        isPublic: true,
      );
      await vm().focusOn(shown);
      expect(state().filter.categories, {dangerous});

      const hidden = MapFocus(
        postId: 'eagle',
        latitude: 12,
        longitude: 123.12,
        isPublic: true,
      );
      await vm().focusOn(hidden);
      expect(state().filter.isActive, isFalse);
      expect(drawn(), all);
      expect(mapboxMapService.focusCalls.last.focus, hidden);
    });

    test('gives the filter sheet one snapshot of lists and counts', () async {
      await vm().onStyleLoaded();
      final choices = vm().filterChoices;
      expect(choices.categoryCounts, {dangerous: 1, inNeed: 2});
      expect(choices.speciesFor({inNeed}).map((o) => o.label), [
        'Philippine eagle',
        MapPinFilter.unknownSpeciesLabel,
      ]);
      expect(choices.speciesFor({}), hasLength(3));
      expect(
        choices.countMatching(const MapPinFilter(categories: {inNeed})),
        2,
      );
      // The only ticked species is not a dangerous animal: the tick is
      // kept, as the map would keep it, so nothing matches.
      expect(
        choices.countMatching(
          const MapPinFilter(
            categories: {dangerous},
            species: {'philippine eagle'},
          ),
        ),
        0,
      );

      // A refresh while the sheet is open does not change its numbers.
      reports.items = [cobra, eagle, unknown, post('new', inNeed)];
      await vm().refreshReports();
      expect(choices.categoryCounts[inNeed], 2);
      expect(
        choices.countMatching(const MapPinFilter(categories: {inNeed})),
        2,
      );
      expect(vm().filterChoices.categoryCounts[inNeed], 3);
    });

    test(
      'a filter picked during a refresh that fails is still drawn',
      () async {
        await vm().onStyleLoaded();
        final gate = reports.gate = Completer<void>();
        reports.fail = true;
        final refreshing = vm().refreshReports();
        await pumpEventQueue();

        await vm().setFilter(const MapPinFilter(categories: {dangerous}));
        expect(drawn(), all);
        gate.complete();
        await refreshing;
        await pumpEventQueue();
        expect(state().reportsHaveError, isTrue);
        expect(drawn(), ['cobra']);
      },
    );

    test(
      'opening a new post while the tab is refreshing waits, then clears a filter hiding it',
      () async {
        await vm().onStyleLoaded();
        await vm().setFilter(const MapPinFilter(categories: {dangerous}));
        final fresh = post('fresh', inNeed, lat: 14);
        reports.items = [cobra, eagle, unknown, fresh];
        final gate = reports.gate = Completer<void>();
        // Opening the Map tab started a refresh.
        final tabRefresh = vm().refreshReports();
        await pumpEventQueue();

        const focus = MapFocus(
          postId: 'fresh',
          latitude: 14,
          longitude: 123.12,
          isPublic: true,
        );
        final focusing = vm().focusOn(focus);
        await pumpEventQueue();
        expect(mapboxMapService.focusCalls, isEmpty);
        gate.complete();
        await tabRefresh;
        await focusing;

        // The focus waited for the tab's refresh and the load after it,
        // and the new post's pin is shown.
        expect(reports.loads, 3);
        expect(state().filter.isActive, isFalse);
        expect(drawn(), contains('fresh'));
        expect(mapboxMapService.focusCalls.last.focus, focus);
      },
    );

    test(
      'a first load hidden by the filter never makes a later refresh jump',
      () async {
        // Picked before the map loaded, e.g. kept from an earlier map.
        await vm().setFilter(
          const MapPinFilter(
            categories: {ReportCategory.otherWildlifeIncident},
          ),
        );
        await vm().onStyleLoaded();
        expect(drawn(), isEmpty);
        expect(mapboxMapService.reportCalls.last.recenter, isFalse);

        await vm().clearFilter();
        expect(drawn(), all);
        await vm().refreshReports();
        expect(mapboxMapService.reportCalls.last.recenter, isFalse);
      },
    );

    test(
      'a refresh removing every ticked species keeps the ticks and hides all pins',
      () async {
        await vm().onStyleLoaded();
        await vm().setFilter(const MapPinFilter(species: {'philippine cobra'}));
        expect(drawn(), ['cobra']);

        reports.items = [eagle, unknown];
        await vm().refreshReports();
        expect(
          state().filter,
          const MapPinFilter(species: {'philippine cobra'}),
        );
        expect(state().visibleReports, isEmpty);
        expect(drawn(), isEmpty);
      },
    );

    test('applying the same filter again retries a failed drawing', () async {
      await vm().onStyleLoaded();
      mapboxMapService.failReports = true;
      await vm().setFilter(const MapPinFilter(categories: {inNeed}));
      mapboxMapService.failReports = false;
      final draws = mapboxMapService.reportCalls.length;

      await vm().setFilter(const MapPinFilter(categories: {inNeed}));
      expect(mapboxMapService.reportCalls, hasLength(draws + 1));
      expect(drawn(), ['eagle', 'unknown']);

      // Drawn now, so the same filter again does nothing.
      await vm().setFilter(const MapPinFilter(categories: {inNeed}));
      expect(mapboxMapService.reportCalls, hasLength(draws + 1));
    });

    test('another account starts without the filter', () async {
      final user = StateProvider<String?>((ref) => 'first');
      final accounts = ProviderContainer(
        overrides: [
          mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
          communityReportsServiceProvider.overrideWithValue(reports),
          currentUserIdProvider.overrideWith(
            (ref) => Stream.value(ref.watch(user)),
          ),
          feedServiceProvider.overrideWithValue(feed),
        ],
      );
      addTearDown(accounts.dispose);
      await accounts.read(currentUserIdProvider.future);
      final map = accounts.read(communityMapViewModelProvider.notifier);
      await map.onStyleLoaded();
      await map.setFilter(const MapPinFilter(categories: {inNeed}));
      expect(drawn(), ['eagle', 'unknown']);

      accounts.read(user.notifier).state = 'second';
      await pumpEventQueue();
      expect(
        accounts.read(communityMapViewModelProvider).filter.isActive,
        isFalse,
      );
      expect(drawn(), all);
    });

    test(
      'a refresh asked for during one loads again, e.g. after hiding a post',
      () async {
        await vm().onStyleLoaded();
        final gate = reports.gate = Completer<void>();
        // Opening the Map tab started a refresh; it loads the old posts.
        final tabRefresh = vm().refreshReports();
        await pumpEventQueue();

        // The cobra post is hidden meanwhile, and hiding asks for a refresh.
        reports.items = [eagle, unknown];
        final afterHide = vm().refreshReports();
        gate.complete();
        await afterHide;
        await tabRefresh;

        expect(reports.loads, 3);
        expect(drawn(), ['eagle', 'unknown']);
        expect(state().reports.map((r) => r.id), ['eagle', 'unknown']);
      },
    );

    test(
      'applying species that are all gone keeps them, showing no pins',
      () async {
        await vm().onStyleLoaded();
        // The sheet still listed the cobra; a refresh removed it meanwhile.
        reports.items = [eagle, unknown];
        await vm().refreshReports();

        await vm().setFilter(const MapPinFilter(species: {'philippine cobra'}));
        expect(
          state().filter,
          const MapPinFilter(species: {'philippine cobra'}),
        );
        expect(state().visibleReports, isEmpty);
        expect(drawn(), isEmpty);
      },
    );

    test(
      'a refresh from an earlier map does not mark a new map as drawn',
      () async {
        // A fake platform map, as in the location picker tests.
        // ignore: invalid_use_of_internal_member
        final firstMap = MapboxMap(FakePickerPlatform());
        // ignore: invalid_use_of_internal_member
        final secondMap = MapboxMap(FakePickerPlatform());
        await vm().onMapCreated(firstMap);
        await vm().onStyleLoaded();
        final draws = mapboxMapService.reportCalls.length;

        // The map is rebuilt while a refresh is still drawing on the old one.
        final gate = mapboxMapService.drawGate = Completer<void>();
        final oldRefresh = vm().refreshReports();
        await pumpEventQueue();
        await vm().onMapCreated(secondMap);
        mapboxMapService.drawGate = null;
        gate.complete();
        await oldRefresh;

        // The new map's style loads: it gets its own drawing.
        await vm().onStyleLoaded();
        expect(mapboxMapService.reportCalls.length, greaterThan(draws + 1));
        expect(drawn(), all);
        // The new map may be framed; the old refresh did not use that up.
        expect(mapboxMapService.reportCalls.last.recenter, isTrue);
      },
    );

    test('pins redrawn after a failed refresh load their photos', () async {
      final photos = _PinPhotos();
      reports.items = [
        post(
          'new',
          dangerous,
          createdAt: DateTime.utc(2026, 11, 20),
          withPhoto: true,
        ),
        post(
          'old',
          inNeed,
          createdAt: DateTime.utc(2026, 11, 1),
          withPhoto: true,
        ),
      ];
      final withPhotos = ProviderContainer(
        overrides: [
          mapboxMapServiceProvider.overrideWithValue(mapboxMapService),
          communityReportsServiceProvider.overrideWithValue(reports),
          currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
          feedServiceProvider.overrideWithValue(feed),
          mapPinPhotoServiceProvider.overrideWithValue(photos),
        ],
      );
      addTearDown(withPhotos.dispose);
      final map = withPhotos.read(communityMapViewModelProvider.notifier);
      await map.onStyleLoaded();
      await pumpEventQueue();
      expect(photos.requests, ['new/photo.webp']);

      final gate = reports.gate = Completer<void>();
      reports.fail = true;
      final refreshing = map.refreshReports();
      await pumpEventQueue();
      await map.setFilter(const MapPinFilter(categories: {inNeed}));
      gate.complete();
      await refreshing;
      await pumpEventQueue();
      expect(drawn(), ['old']);
      expect(photos.requests, ['new/photo.webp', 'old/photo.webp']);
    });
  });
}

class _FakeMapboxMapService implements MapboxMapService {
  MapBounds? bounds = (south: -90, west: -180, north: 90, east: 180);
  final boundsRequests = <int>[];
  @override
  Future<MapBounds?> visibleBounds() async {
    boundsRequests.add(boundsRequests.length);
    return bounds;
  }

  final photoCalls = <Map<String, StyleImage>>[];
  @override
  Future<void> showPinPhotos(Map<String, StyleImage> photos) async {
    photoCalls.add(Map.of(photos));
  }

  final focusCalls = <({MapFocus? focus, bool moveCamera})>[];
  @override
  Future<void> showFocus(MapFocus? focus, {bool moveCamera = true}) async {
    focusCalls.add((focus: focus, moveCamera: moveCamera));
  }

  final locations = <GuardLocation?>[];
  @override
  Future<void> showGuardLocation(GuardLocation? location) async {
    locations.add(location);
  }

  final radiusCalls = <List<CommunityReport>>[];
  @override
  Future<void> showGuardRadius(List<CommunityReport> reports) async {
    radiusCalls.add(reports);
  }

  /// Holds the next drawing of the pins until completed.
  Completer<void>? drawGate;

  @override
  Future<void> showReports(
    List<CommunityReport> reports, {
    bool recenter = false,
  }) async {
    reportCalls.add((reports: reports, recenter: recenter));
    await drawGate?.future;
    if (failReports) throw StateError('Unavailable');
  }

  final List<({Brightness brightness, bool is3dEnabled})> appearanceCalls = [];
  final reportCalls = <({List<CommunityReport> reports, bool recenter})>[];
  bool failReports = false;

  @override
  Future<void> applyAppearance({
    required Brightness brightness,
    required bool is3dEnabled,
  }) async {
    appearanceCalls.add((brightness: brightness, is3dEnabled: is3dEnabled));
  }

  @override
  Future<void> attach(
    MapboxMap mapboxMap, {
    void Function(String)? onPostTap,
  }) async {}

  @override
  void detach() {}
}

class _Reports implements CommunityReportsService {
  bool fail = false;
  int loads = 0;
  List<CommunityReport> items = [_report];

  /// Holds the next load until completed.
  Completer<void>? gate;
  @override
  Future<List<CommunityReport>> load() async {
    loads++;
    final wait = gate;
    gate = null;
    await wait?.future;
    if (fail) throw StateError('offline');
    return items;
  }
}

const _report = CommunityReport(
  id: 'approved',
  category: 'animal_in_need',
  latitude: 10.12,
  longitude: 123.12,
  description: 'Bird',
);

class _OwnLocations implements ReportDetailService {
  final points = <String, ({double latitude, double longitude})>{};
  final requests = <String>[];
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<({double latitude, double longitude})?> fetchOwnLocation(
    String reportId,
  ) async {
    requests.add(reportId);
    await gate?.future;
    if (fail) throw StateError('offline');
    return points[reportId];
  }

  @override
  Future<OwnReport?> fetchOwnReport(String reportId) async => null;
}

class _PinPhotos implements MapPinPhotoService {
  final requests = <String>[];

  /// Photos that cannot be loaded.
  final failing = <String>{};
  Completer<void>? gate;

  @override
  Future<StyleImage?> loadPin(String photoPath) async {
    requests.add(photoPath);
    await gate?.future;
    if (failing.contains(photoPath)) return null;
    return StyleImage.rgba(
      width: 1,
      height: 1,
      pixels: Uint8List.fromList([0, 0, 0, 255]),
    );
  }
}
