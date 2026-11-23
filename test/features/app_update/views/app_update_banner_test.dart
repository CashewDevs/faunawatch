import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/models/update_reminder.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/app_update_installer.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:faunawatch/features/app_update/services/update_reminder_service.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:faunawatch/features/app_update/views/widgets/app_update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_update_fakes.dart';

const installed = AppVersion(1, 0, 0, build: 4);
const v5 = AppVersion(1, 0, 0, build: 5);

void main() {
  late FakeAppReleaseService releases;
  late FakeUpdateReminderService reminders;
  final now = DateTime(2026, 11, 23, 12);

  Widget buildBanner({bool supported = true}) {
    return ProviderScope(
      overrides: [
        installedVersionServiceProvider.overrideWithValue(
          FakeInstalledVersionService(installed),
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
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppUpdateBanner(),
              Expanded(child: Text('feed')),
            ],
          ),
        ),
      ),
    );
  }

  setUp(() {
    releases = FakeAppReleaseService();
    reminders = FakeUpdateReminderService();
  });

  testWidgets('checks when shown and offers the newer version', (tester) async {
    releases.release = testRelease(version: v5, apkUrl: testApkUrl);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    expect(releases.calls, 1);
    expect(find.text('FaunaWatch 1.0.0 (5) is ready'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.byTooltip('Hide update notice'), findsOneWidget);
  });

  testWidgets('takes no space when there is nothing newer', (tester) async {
    releases.release = testRelease(version: installed);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    expect(find.textContaining('is ready'), findsNothing);
    expect(tester.getTopLeft(find.text('feed')).dy, 0);
  });

  testWidgets('shows nothing where updates are not supported', (tester) async {
    releases.release = testRelease(version: v5);
    await tester.pumpWidget(buildBanner(supported: false));
    await tester.pumpAndSettle();

    expect(releases.calls, 0);
    expect(find.textContaining('is ready'), findsNothing);
  });

  testWidgets('the close button hides it for this version', (tester) async {
    releases.release = testRelease(version: v5);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hide update notice'));
    await tester.pumpAndSettle();

    expect(find.textContaining('is ready'), findsNothing);
    expect(reminders.dismissedSaves, [v5]);
  });

  testWidgets('Update opens the Update available box', (tester) async {
    releases.release = testRelease(version: v5, apkUrl: testApkUrl);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(
      find.text('Version 1.0.0 (5) is ready. You have 1.0.0 (4).'),
      findsOneWidget,
    );
  });

  testWidgets('Update after a saved answer loads the release first', (
    tester,
  ) async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    releases.release = testRelease(version: v5, apkUrl: testApkUrl);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();
    expect(releases.calls, 0);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(releases.calls, 1);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('Update says so when the version is no longer newer', (
    tester,
  ) async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    releases.release = testRelease(version: installed);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(find.text('FaunaWatch is up to date.'), findsOneWidget);
    expect(find.textContaining('is ready'), findsNothing);
  });

  testWidgets('Update says so when GitHub cannot be reached', (tester) async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    releases.error = const AppReleaseException('offline');
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't check for updates. Try again from Settings."),
      findsOneWidget,
    );
    expect(find.text('FaunaWatch 1.0.0 (5) is ready'), findsOneWidget);
  });
}
