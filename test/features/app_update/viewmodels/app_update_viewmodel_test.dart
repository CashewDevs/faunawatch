import 'dart:async';

import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/app_update_installer.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:faunawatch/features/app_update/services/update_reminder_service.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_update_fakes.dart';

const installed = AppVersion(1, 0, 0, build: 2);

void main() {
  late FakeAppReleaseService releases;
  late FakeExternalLinkService links;
  late FakeAppUpdateInstaller installer;
  late FakeUpdateReminderService reminders;
  var now = DateTime(2026, 11, 23, 12);

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
        appUpdateInstallerProvider.overrideWithValue(installer),
        updateReminderServiceProvider.overrideWithValue(reminders),
        appUpdateClockProvider.overrideWithValue(() => now),
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
    installer = FakeAppUpdateInstaller();
    reminders = FakeUpdateReminderService();
    now = DateTime(2026, 11, 23, 12);
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

  group('installing', () {
    AppUpdateState stateOf(ProviderContainer container) =>
        container.read(appUpdateViewModelProvider);

    Future<ProviderContainer> withNewerRelease({Uri? apkUrl}) async {
      releases.release = testRelease(apkUrl: apkUrl ?? testApkUrl);
      final container = await containerWith();
      await viewModel(container).checkForUpdates();
      return container;
    }

    test('clears old downloads when it starts, only where supported', () async {
      await containerWith();
      expect(installer.clears, 1);

      installer = FakeAppUpdateInstaller();
      await containerWith(supported: false);
      expect(installer.clears, 0);
    });

    test('downloads the apk and opens the installer', () async {
      final container = await withNewerRelease();
      expect(stateOf(container).canUpdateInApp, isTrue);

      await viewModel(container).startUpdate();

      expect(installer.downloads, [testApkUrl]);
      expect(installer.installs, [FakeAppUpdateInstaller.downloadedPath]);
      final state = stateOf(container);
      expect(state.installStatus, UpdateInstallStatus.installing);
      expect(state.downloadedPath, FakeAppUpdateInstaller.downloadedPath);
    });

    test('does nothing for a release without an apk', () async {
      releases.release = testRelease();
      final container = await containerWith();
      await viewModel(container).checkForUpdates();
      expect(stateOf(container).canUpdateInApp, isFalse);

      await viewModel(container).startUpdate();

      expect(installer.downloads, isEmpty);
      expect(stateOf(container).installStatus, UpdateInstallStatus.idle);
    });

    test('shows download progress and can be cancelled', () async {
      installer.gate = Completer<void>();
      final container = await withNewerRelease();

      final update = viewModel(container).startUpdate();
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(container).installStatus, UpdateInstallStatus.downloading);
      expect(stateOf(container).downloadProgress, 0.5);

      // A second tap does not start another download.
      await viewModel(container).startUpdate();
      expect(installer.downloads, hasLength(1));

      viewModel(container).cancelDownload();
      await update;

      final state = stateOf(container);
      expect(state.installStatus, UpdateInstallStatus.idle);
      expect(state.downloadProgress, isNull);
      expect(state.downloadedPath, isNull);
      expect(installer.installs, isEmpty);
    });

    test('a failed download can be tried again', () async {
      installer.downloadError = const AppUpdateInstallException(
        AppUpdateInstallFailure.downloadFailed,
        'offline',
      );
      final container = await withNewerRelease();

      await viewModel(container).startUpdate();
      expect(stateOf(container).installStatus, UpdateInstallStatus.failed);
      expect(
        stateOf(container).installFailure,
        AppUpdateInstallFailure.downloadFailed,
      );

      installer.downloadError = null;
      await viewModel(container).startUpdate();
      expect(stateOf(container).installStatus, UpdateInstallStatus.installing);
      expect(stateOf(container).installFailure, isNull);
    });

    test('asks for permission first, without downloading again', () async {
      installer.allowed = false;
      final container = await withNewerRelease();

      await viewModel(container).startUpdate();
      expect(
        stateOf(container).installStatus,
        UpdateInstallStatus.needsPermission,
      );
      expect(installer.installs, isEmpty);

      expect(stateOf(container).permissionStillMissing, isFalse);
      expect(installer.installs, isEmpty);

      await viewModel(container).openInstallSettings();
      expect(installer.settingsOpened, 1);

      // Back from settings, still not allowed: say so.
      await viewModel(container).recheckInstallPermission();
      expect(
        stateOf(container).installStatus,
        UpdateInstallStatus.needsPermission,
      );
      expect(stateOf(container).permissionStillMissing, isTrue);

      // Back from settings, allowed: the installer opens by itself.
      installer.allowed = true;
      await viewModel(container).recheckInstallPermission();
      expect(stateOf(container).installStatus, UpdateInstallStatus.installing);
      expect(stateOf(container).permissionStillMissing, isFalse);
      expect(installer.downloads, hasLength(1));
      expect(installer.installs, [FakeAppUpdateInstaller.downloadedPath]);
    });

    test(
      'rechecking does nothing unless the permission is asked for',
      () async {
        final container = await withNewerRelease();

        await viewModel(container).recheckInstallPermission();
        expect(stateOf(container).installStatus, UpdateInstallStatus.idle);

        await viewModel(container).startUpdate();
        await viewModel(container).recheckInstallPermission();
        expect(
          stateOf(container).installStatus,
          UpdateInstallStatus.installing,
        );
        // Coming back from Android's installer does not open it again.
        expect(installer.installs, hasLength(1));
      },
    );

    test('an installer that cannot open is reported and retried', () async {
      installer.installError = const AppUpdateInstallException(
        AppUpdateInstallFailure.installFailed,
        'no installer',
      );
      final container = await withNewerRelease();

      await viewModel(container).startUpdate();
      expect(
        stateOf(container).installFailure,
        AppUpdateInstallFailure.installFailed,
      );

      installer.installError = null;
      await viewModel(container).startUpdate();
      expect(stateOf(container).installStatus, UpdateInstallStatus.installing);
      expect(installer.downloads, hasLength(1));
    });

    test('a new check starts over and is ignored while downloading', () async {
      installer.gate = Completer<void>();
      final container = await withNewerRelease();

      final update = viewModel(container).startUpdate();
      await Future<void>.delayed(Duration.zero);
      await viewModel(container).checkForUpdates();
      expect(releases.calls, 1);

      installer.gate!.complete();
      await update;
      expect(stateOf(container).installStatus, UpdateInstallStatus.installing);

      await viewModel(container).checkForUpdates();
      final state = stateOf(container);
      expect(releases.calls, 2);
      expect(state.installStatus, UpdateInstallStatus.idle);
      expect(state.downloadedPath, isNull);
    });
  });
}
