import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/models/update_reminder.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/app_update_installer.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:faunawatch/features/app_update/services/update_reminder_service.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_update_fakes.dart';

const installed = AppVersion(1, 0, 0, build: 4);
const v5 = AppVersion(1, 0, 0, build: 5);
const v6 = AppVersion(1, 0, 0, build: 6);

void main() {
  late FakeAppReleaseService releases;
  late FakeUpdateReminderService reminders;
  late DateTime now;

  ProviderContainer containerWith({
    AppVersion? version = installed,
    bool supported = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        installedVersionServiceProvider.overrideWithValue(
          FakeInstalledVersionService(version),
        ),
        appReleaseServiceProvider.overrideWithValue(releases),
        externalLinkServiceProvider.overrideWithValue(
          FakeExternalLinkService(),
        ),
        appUpdateInstallerProvider.overrideWithValue(FakeAppUpdateInstaller()),
        updateReminderServiceProvider.overrideWithValue(reminders),
        appUpdateClockProvider.overrideWithValue(() => now),
        selfUpdateSupportedProvider.overrideWithValue(supported),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  AppUpdateViewModel viewModel(ProviderContainer container) =>
      container.read(appUpdateViewModelProvider.notifier);

  AppUpdateState stateOf(ProviderContainer container) =>
      container.read(appUpdateViewModelProvider);

  setUp(() {
    releases = FakeAppReleaseService();
    reminders = FakeUpdateReminderService();
    now = DateTime(2026, 11, 23, 12);
  });

  test('asks GitHub, remembers the answer and shows the banner', () async {
    releases.release = testRelease(version: v5, apkUrl: testApkUrl);
    final container = containerWith();

    await viewModel(container).autoCheck();

    expect(releases.calls, 1);
    expect(reminders.reminder.lastCheckedAt, now);
    expect(reminders.reminder.lastFound, v5);
    final state = stateOf(container);
    expect(state.notice, v5);
    // The Settings row and the Update box are ready too.
    expect(state.status, UpdateCheckStatus.available);
    expect(state.latest?.version, v5);
  });

  test('shows no banner when the app is up to date', () async {
    releases.release = testRelease(version: installed);
    final container = containerWith();

    await viewModel(container).autoCheck();

    expect(stateOf(container).notice, isNull);
    expect(stateOf(container).status, UpdateCheckStatus.idle);
    expect(reminders.reminder.lastFound, installed);
  });

  test('within six hours reuses the last answer without asking', () async {
    reminders.reminder = UpdateReminder(
      lastCheckedAt: now.subtract(const Duration(hours: 2)),
      lastFound: v5,
    );
    final container = containerWith();

    await viewModel(container).autoCheck();

    expect(releases.calls, 0);
    expect(stateOf(container).notice, v5);
    // The release details are loaded only when Update is tapped.
    expect(stateOf(container).latest, isNull);
  });

  test('after six hours asks again', () async {
    reminders.reminder = UpdateReminder(
      lastCheckedAt: now.subtract(const Duration(hours: 7)),
      lastFound: v5,
    );
    releases.release = testRelease(version: v6);
    final container = containerWith();

    await viewModel(container).autoCheck();

    expect(releases.calls, 1);
    expect(stateOf(container).notice, v6);
  });

  test('stays hidden for a closed version, shows an even newer one', () async {
    reminders.reminder = const UpdateReminder(dismissed: v5);
    releases.release = testRelease(version: v5);
    var container = containerWith();
    await viewModel(container).autoCheck();
    expect(stateOf(container).notice, isNull);

    now = now.add(const Duration(hours: 7));
    releases.release = testRelease(version: v6);
    container = containerWith();
    await viewModel(container).autoCheck();
    expect(stateOf(container).notice, v6);
  });

  test('offline: stays quiet and falls back to the last answer', () async {
    reminders.reminder = UpdateReminder(
      lastCheckedAt: now.subtract(const Duration(days: 1)),
      lastFound: v5,
    );
    releases.error = const AppReleaseException('offline');
    final container = containerWith();

    await viewModel(container).autoCheck();

    expect(stateOf(container).notice, v5);
    expect(stateOf(container).status, UpdateCheckStatus.idle);
    // Not saved, so the next launch tries again.
    expect(reminders.checkSaves, 0);
  });

  test('runs once per session', () async {
    final container = containerWith();

    await viewModel(container).autoCheck();
    now = now.add(const Duration(hours: 7));
    await viewModel(container).autoCheck();

    expect(releases.calls, 1);
  });

  test('does nothing where updates are not supported or unknown', () async {
    await viewModel(containerWith(supported: false)).autoCheck();
    await viewModel(containerWith(version: null)).autoCheck();

    expect(releases.calls, 0);
    expect(reminders.checkSaves, 0);
  });

  test('closing the banner hides it and remembers the version', () async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    final container = containerWith();
    await viewModel(container).autoCheck();

    await viewModel(container).dismissNotice();

    expect(stateOf(container).notice, isNull);
    expect(reminders.dismissedSaves, [v5]);
  });

  test('loadNewerRelease loads the details behind the banner', () async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    releases.release = testRelease(version: v5, apkUrl: testApkUrl);
    final container = containerWith();
    await viewModel(container).autoCheck();

    expect(await viewModel(container).loadNewerRelease(), isTrue);
    expect(stateOf(container).latest?.version, v5);
    expect(releases.calls, 1);

    // Already loaded: GitHub is not asked again.
    expect(await viewModel(container).loadNewerRelease(), isTrue);
    expect(releases.calls, 1);
  });

  test('a check that finds nothing newer hides an outdated banner', () async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    releases.release = testRelease(version: installed);
    final container = containerWith();
    await viewModel(container).autoCheck();
    expect(stateOf(container).notice, v5);

    expect(await viewModel(container).loadNewerRelease(), isFalse);

    expect(stateOf(container).notice, isNull);
    expect(stateOf(container).status, UpdateCheckStatus.upToDate);
    expect(reminders.reminder.lastFound, installed);
  });
}
