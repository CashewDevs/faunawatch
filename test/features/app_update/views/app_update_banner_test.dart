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

  Widget buildBanner({bool supported = true, bool reduceMotion = false}) {
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
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const Scaffold(
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

  double feedTop(WidgetTester tester) =>
      tester.getTopLeft(find.text('feed')).dy;

  setUp(() {
    releases = FakeAppReleaseService();
    reminders = FakeUpdateReminderService();
  });

  testWidgets('shows the big card with the version and the notes', (
    tester,
  ) async {
    releases.release = testRelease(
      version: v5,
      apkUrl: testApkUrl,
      notes: '- Faster map\n- New banner',
    );
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    expect(releases.calls, 1);
    expect(find.text('New version available'), findsOneWidget);
    expect(find.text('FaunaWatch 1.0.0 (5) is ready'), findsOneWidget);
    expect(find.text('Faster map'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    // A big card, not a thin strip.
    expect(feedTop(tester), greaterThan(150));
  });

  testWidgets('waits a moment, then slides down and pushes the feed', (
    tester,
  ) async {
    releases.release = testRelease(version: v5);
    await tester.pumpWidget(buildBanner());
    await tester.pump(); // first frame: starts the check
    await tester.pump(); // the check finishes

    // During the pause the card is there but takes no space yet.
    await tester.pump(const Duration(milliseconds: 300));
    expect(feedTop(tester), 0);

    // Halfway through sliding in.
    await tester.pump(const Duration(milliseconds: 300));
    final halfway = feedTop(tester);
    expect(halfway, greaterThan(0));

    await tester.pumpAndSettle();
    expect(feedTop(tester), greaterThan(halfway));
  });

  testWidgets('appears at once when the device asks for less motion', (
    tester,
  ) async {
    releases.release = testRelease(version: v5);
    await tester.pumpWidget(buildBanner(reduceMotion: true));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('New version available'), findsOneWidget);
    expect(feedTop(tester), greaterThan(150));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('takes no space when there is nothing newer', (tester) async {
    releases.release = testRelease(version: installed);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    expect(find.text('New version available'), findsNothing);
    expect(feedTop(tester), 0);
  });

  testWidgets('shows nothing where updates are not supported', (tester) async {
    releases.release = testRelease(version: v5);
    await tester.pumpWidget(buildBanner(supported: false));
    await tester.pumpAndSettle();

    expect(releases.calls, 0);
    expect(find.text('New version available'), findsNothing);
  });

  testWidgets('Not now slides it away without saving anything', (tester) async {
    releases.release = testRelease(version: v5);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();
    final savesBefore = reminders.checkSaves;

    await tester.tap(find.text('Not now'));
    await tester.pump(const Duration(milliseconds: 150));
    // Still sliding away.
    expect(find.text('New version available'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('New version available'), findsNothing);
    expect(feedTop(tester), 0);
    expect(reminders.checkSaves, savesBefore);
  });

  testWidgets('comes back on the next launch after Not now', (tester) async {
    releases.release = testRelease(version: v5);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // A fresh app (new ProviderScope) within six hours.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    expect(find.text('New version available'), findsOneWidget);
    expect(releases.calls, 1);
  });

  testWidgets('Update now opens the Update available box', (tester) async {
    releases.release = testRelease(version: v5, apkUrl: testApkUrl);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(
      find.text('Version 1.0.0 (5) is ready. You have 1.0.0 (4).'),
      findsOneWidget,
    );
  });

  testWidgets('Update now after a saved answer loads the release first', (
    tester,
  ) async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    releases.release = testRelease(version: v5, apkUrl: testApkUrl);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();
    expect(releases.calls, 0);

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(releases.calls, 1);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('Update now says so when the version is no longer newer', (
    tester,
  ) async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    releases.release = testRelease(version: installed);
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(find.text('FaunaWatch is up to date.'), findsOneWidget);
    expect(find.text('New version available'), findsNothing);
  });

  testWidgets('Update now says so when GitHub cannot be reached', (
    tester,
  ) async {
    reminders.reminder = UpdateReminder(lastCheckedAt: now, lastFound: v5);
    releases.error = const AppReleaseException('offline');
    await tester.pumpWidget(buildBanner());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't check for updates. Try again from Settings."),
      findsOneWidget,
    );
    expect(find.text('New version available'), findsOneWidget);
  });
}
