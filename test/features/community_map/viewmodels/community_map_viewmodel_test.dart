import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/models/map_post_preview.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import '../../feed/fake_feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
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
      expect(vm.selectedPreview!.isDemo, isFalse);
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

  test(
    'selects only the demo pin or a loaded report, and can dismiss',
    () async {
      final vm = container.read(communityMapViewModelProvider.notifier);
      vm.selectPost('unknown');
      expect(
        container.read(communityMapViewModelProvider).selectedPostId,
        isNull,
      );
      vm.selectPost(MapPostPreview.demoId);
      expect(
        container.read(communityMapViewModelProvider).selectedPostId,
        MapPostPreview.demoId,
      );
      expect(vm.selectedPreview, same(MapPostPreview.demo));
      expect(vm.selectedPreview!.isDemo, isTrue);
      vm.dismissPost();
      expect(
        container.read(communityMapViewModelProvider).selectedPostId,
        isNull,
      );
    },
  );

  test('see more does nothing without a selection or for the demo pin', () {
    final vm = container.read(communityMapViewModelProvider.notifier);
    container
        .read(shellViewModelProvider.notifier)
        .selectDestination(ShellDestination.chats);
    vm.seeMore();
    vm.selectPost(MapPostPreview.demoId);
    vm.seeMore();
    expect(container.read(shellViewModelProvider), ShellDestination.chats);
    expect(container.read(feedViewModelProvider).focusedPostId, isNull);
  });

  test('starts in 3D mode using the light appearance', () {
    final state = container.read(communityMapViewModelProvider);

    expect(state.is3dEnabled, isTrue);
    expect(state.brightness, Brightness.light);
    expect(state.demoLevel, DemoWarningLevel.approaching);
  });

  test('waits for the style then renders the selected demo level', () async {
    final viewModel = container.read(communityMapViewModelProvider.notifier);
    await viewModel.selectDemoLevel(DemoWarningLevel.danger);
    expect(mapboxMapService.demoCalls, isEmpty);
    await viewModel.onStyleLoaded();
    expect(mapboxMapService.demoCalls.single.level, DemoWarningLevel.danger);
    await viewModel.selectDemoLevel(DemoWarningLevel.near);
    expect(mapboxMapService.demoCalls.last.level, DemoWarningLevel.near);
    expect(
      container.read(communityMapViewModelProvider).demoLevel,
      DemoWarningLevel.near,
    );
  });

  test('a failed demo draw can be retried by recentering', () async {
    final viewModel = container.read(communityMapViewModelProvider.notifier);
    mapboxMapService.failDemo = true;
    await viewModel.onStyleLoaded();
    expect(container.read(communityMapViewModelProvider).demoHasError, isTrue);
    mapboxMapService.failDemo = false;
    await viewModel.recenterDemo();
    expect(mapboxMapService.demoCalls.last.recenter, isTrue);
    expect(container.read(communityMapViewModelProvider).demoHasError, isFalse);
  });

  test(
    'rapid selections finish with the newest level and no concurrent draws',
    () async {
      final viewModel = container.read(communityMapViewModelProvider.notifier);
      await viewModel.onStyleLoaded();
      await Future.wait([
        viewModel.selectDemoLevel(DemoWarningLevel.near),
        viewModel.selectDemoLevel(DemoWarningLevel.danger),
      ]);
      expect(mapboxMapService.demoCalls.last.level, DemoWarningLevel.danger);
      expect(mapboxMapService.maxConcurrentDraws, 1);
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
}

class _FakeMapboxMapService implements MapboxMapService {
  @override
  Future<void> showReports(List<CommunityReport> reports) async {}
  final List<({Brightness brightness, bool is3dEnabled})> appearanceCalls = [];
  final demoCalls = <({DemoWarningLevel level, bool recenter})>[];
  bool failDemo = false;
  int concurrentDraws = 0;
  int maxConcurrentDraws = 0;

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

  @override
  Future<void> showWarningDemo(
    DemoWarningLevel level, {
    bool recenter = false,
  }) async {
    demoCalls.add((level: level, recenter: recenter));
    concurrentDraws++;
    if (concurrentDraws > maxConcurrentDraws) {
      maxConcurrentDraws = concurrentDraws;
    }
    try {
      await Future<void>.delayed(Duration.zero);
      if (failDemo) throw StateError('Unavailable');
    } finally {
      concurrentDraws--;
    }
  }
}

class _Reports implements CommunityReportsService {
  bool fail = false;
  @override
  Future<List<CommunityReport>> load() async {
    if (fail) throw StateError('offline');
    return const [
      CommunityReport(
        id: 'approved',
        category: 'animal_in_need',
        latitude: 10.12,
        longitude: 123.12,
        description: 'Bird',
      ),
    ];
  }
}
