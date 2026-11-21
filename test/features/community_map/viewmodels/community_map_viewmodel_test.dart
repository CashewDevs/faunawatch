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
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/models/community_map_state.dart';
import 'package:faunawatch/features/community_map/models/map_focus.dart';
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
      expect(container.read(feedTabViewModelProvider), FeedTab.forYou);
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
      await open([for (var i = 0; i < 6; i++) photoReport('r$i')], gate: gate);
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
      expect(container.read(shellViewModelProvider), ShellDestination.feed);
      expect(container.read(feedTabViewModelProvider), FeedTab.map);
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
          expect(owner.read(feedTabViewModelProvider), FeedTab.map);
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

  @override
  Future<void> showReports(
    List<CommunityReport> reports, {
    bool recenter = false,
  }) async {
    reportCalls.add((reports: reports, recenter: recenter));
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
  List<CommunityReport> items = [_report];
  @override
  Future<List<CommunityReport>> load() async {
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
