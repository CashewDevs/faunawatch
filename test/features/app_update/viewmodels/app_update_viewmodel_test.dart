import 'dart:async';

import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_update_fakes.dart';

const installed = AppVersion(1, 0, 0, build: 2);

void main() {
  late FakeAppReleaseService releases;
  late FakeExternalLinkService links;

  Future<ProviderContainer> containerWith({
    AppVersion? version = installed,
    bool supported = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        installedVersionServiceProvider.overrideWithValue(
          FakeInstalledVersionService(version),
        ),
        appReleaseServiceProvider.overrideWithValue(releases),
        externalLinkServiceProvider.overrideWithValue(links),
        selfUpdateSupportedProvider.overrideWithValue(supported),
      ],
    );
    addTearDown(container.dispose);
    container.read(appUpdateViewModelProvider);
    // Let the installed version load.
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  AppUpdateViewModel viewModel(ProviderContainer container) =>
      container.read(appUpdateViewModelProvider.notifier);

  setUp(() {
    releases = FakeAppReleaseService();
    links = FakeExternalLinkService();
  });

  test('loads the installed version without checking GitHub', () async {
    final container = await containerWith();

    final state = container.read(appUpdateViewModelProvider);
    expect(state.installed, installed);
    expect(state.status, UpdateCheckStatus.idle);
    expect(state.canCheck, isTrue);
    expect(releases.calls, 0);
  });

  test('offers no check when updates are not supported', () async {
    final container = await containerWith(supported: false);

    expect(container.read(appUpdateViewModelProvider).canCheck, isFalse);
    await viewModel(container).checkForUpdates();
    expect(releases.calls, 0);
  });

  test('offers no check when the installed version is unknown', () async {
    final container = await containerWith(version: null);

    expect(container.read(appUpdateViewModelProvider).canCheck, isFalse);
    await viewModel(container).checkForUpdates();
    expect(releases.calls, 0);
  });

  test('reports a newer release as available', () async {
    final release = testRelease();
    releases.release = release;
    final container = await containerWith();

    await viewModel(container).checkForUpdates();

    final state = container.read(appUpdateViewModelProvider);
    expect(state.status, UpdateCheckStatus.available);
    expect(state.latest, same(release));
  });

  test('reports up to date for the same or an older release', () async {
    for (final version in const [installed, AppVersion(0, 9, 0, build: 9)]) {
      releases.release = testRelease(version: version);
      final container = await containerWith();

      await viewModel(container).checkForUpdates();

      final state = container.read(appUpdateViewModelProvider);
      expect(state.status, UpdateCheckStatus.upToDate, reason: '$version');
      expect(state.latest, isNull);
    }
  });

  test('reports up to date when nothing has been released yet', () async {
    final container = await containerWith();

    await viewModel(container).checkForUpdates();

    expect(
      container.read(appUpdateViewModelProvider).status,
      UpdateCheckStatus.upToDate,
    );
  });

  test('reports a failed check, and a retry can succeed', () async {
    releases.error = const AppReleaseException('offline');
    final container = await containerWith();

    await viewModel(container).checkForUpdates();
    expect(
      container.read(appUpdateViewModelProvider).status,
      UpdateCheckStatus.failed,
    );

    releases
      ..error = null
      ..release = testRelease();
    await viewModel(container).checkForUpdates();
    expect(
      container.read(appUpdateViewModelProvider).status,
      UpdateCheckStatus.available,
    );
  });

  test('shows checking while waiting and ignores a second tap', () async {
    releases.gate = Completer<void>();
    final container = await containerWith();

    final first = viewModel(container).checkForUpdates();
    expect(
      container.read(appUpdateViewModelProvider).status,
      UpdateCheckStatus.checking,
    );
    await viewModel(container).checkForUpdates();
    expect(releases.calls, 1);

    releases.gate!.complete();
    await first;
    expect(
      container.read(appUpdateViewModelProvider).status,
      UpdateCheckStatus.upToDate,
    );
  });

  test('opens the newer release page', () async {
    final release = testRelease();
    releases.release = release;
    final container = await containerWith();

    expect(await viewModel(container).openReleasePage(), isFalse);
    expect(links.opened, isEmpty);

    await viewModel(container).checkForUpdates();
    expect(await viewModel(container).openReleasePage(), isTrue);
    expect(links.opened, [release.pageUrl]);
  });
}
