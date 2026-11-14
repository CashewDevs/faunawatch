import 'package:flutter/material.dart';
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
}

class _FakeMapboxMapService implements MapboxMapService {
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
