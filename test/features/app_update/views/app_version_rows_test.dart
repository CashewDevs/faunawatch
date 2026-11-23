import 'dart:async';

import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/app_update_installer.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:faunawatch/features/app_update/views/widgets/app_version_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_update_fakes.dart';

void main() {
  late FakeAppReleaseService releases;
  late FakeExternalLinkService links;
  late FakeAppUpdateInstaller installer;

  Widget buildRows({
    AppVersion? version = const AppVersion(1, 0, 0, build: 2),
    bool supported = true,
  }) {
    return ProviderScope(
      overrides: [
        installedVersionServiceProvider.overrideWithValue(
          FakeInstalledVersionService(version),
        ),
        appReleaseServiceProvider.overrideWithValue(releases),
        externalLinkServiceProvider.overrideWithValue(links),
        selfUpdateSupportedProvider.overrideWithValue(supported),
        appUpdateInstallerProvider.overrideWithValue(installer),
      ],
      child: const MaterialApp(home: Scaffold(body: AppVersionRows())),
    );
  }

  setUp(() {
    releases = FakeAppReleaseService();
    links = FakeExternalLinkService();
    installer = FakeAppUpdateInstaller();
  });

  testWidgets('shows the installed version and Check for updates', (
    tester,
  ) async {
    await tester.pumpWidget(buildRows());
    await tester.pumpAndSettle();

    expect(find.text('FaunaWatch Version'), findsOneWidget);
    expect(find.text('1.0.0 (2)'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('See if a newer version is out'), findsOneWidget);
  });

  testWidgets('hides Check for updates where updates are not supported', (
    tester,
  ) async {
    await tester.pumpWidget(buildRows(supported: false));
    await tester.pumpAndSettle();

    expect(find.text('1.0.0 (2)'), findsOneWidget);
    expect(find.text('Check for updates'), findsNothing);
  });

  testWidgets('says up to date when there is nothing newer', (tester) async {
    releases.release = testRelease(
      version: const AppVersion(1, 0, 0, build: 2),
    );
    await tester.pumpWidget(buildRows());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text("You're up to date"), findsOneWidget);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('says the check failed', (tester) async {
    releases.error = const AppReleaseException('offline');
    await tester.pumpWidget(buildRows());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't check. Tap to try again."), findsOneWidget);
  });

  testWidgets(
    'opens Update available with notes, and the download page from it',
    (tester) async {
      final release = testRelease();
      releases.release = release;
      await tester.pumpWidget(buildRows());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);
      expect(
        find.text('Version 1.0.1 (3) is ready. You have 1.0.0 (2).'),
        findsOneWidget,
      );
      expect(find.text('Faster map.'), findsOneWidget);
      expect(find.text('Version 1.0.1 (3) is ready'), findsOneWidget);

      await tester.tap(find.text('Open download page'));
      await tester.pumpAndSettle();

      expect(links.opened, [release.pageUrl]);
      expect(find.text('Update available'), findsNothing);

      // Tapping again reopens the box without asking GitHub again.
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      expect(releases.calls, 1);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets('tells the user when the download page cannot open', (
    tester,
  ) async {
    links = FakeExternalLinkService(result: false);
    releases.release = testRelease();
    await tester.pumpWidget(buildRows());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open download page'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't open the download page."), findsOneWidget);
  });

  group('Update button', () {
    Future<void> openUpdateBox(WidgetTester tester) async {
      releases.release = testRelease(apkUrl: testApkUrl);
      await tester.pumpWidget(buildRows());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers Update instead of the download page', (tester) async {
      await openUpdateBox(tester);

      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Open download page'), findsNothing);
    });

    testWidgets('shows progress, cannot be closed, and can be cancelled', (
      tester,
    ) async {
      installer.gate = Completer<void>();
      await openUpdateBox(tester);

      await tester.tap(find.text('Update'));
      await tester.pump();

      expect(find.text('Downloading update'), findsOneWidget);
      expect(find.text('Downloading version 1.0.1 (3)… 50%'), findsOneWidget);
      expect(find.text('Downloading… 50%'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);

      // Tapping outside or Back does not hide a running download.
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.text('Downloading update'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(installer.installs, isEmpty);
    });

    testWidgets('opens the installer when the download finishes', (
      tester,
    ) async {
      await openUpdateBox(tester);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(installer.installs, [FakeAppUpdateInstaller.downloadedPath]);
      expect(find.text('Finish in the installer'), findsOneWidget);

      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      expect(installer.installs, hasLength(2));
      expect(installer.downloads, hasLength(1));
    });

    const stillMissing =
        "FaunaWatch still isn't allowed to install apps. Tap Open settings "
        'and turn on "Allow from this source".';

    /// The user leaves for Android settings and comes back.
    Future<void> returnFromSettings(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('asks for permission with only Open settings', (tester) async {
      installer.allowed = false;
      await openUpdateBox(tester);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(find.text('One more step'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Install'), findsNothing);
      expect(find.text(stillMissing), findsNothing);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(installer.settingsOpened, 1);
    });

    testWidgets('says the permission is still missing on return', (
      tester,
    ) async {
      installer.allowed = false;
      await openUpdateBox(tester);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      await returnFromSettings(tester);

      expect(find.text('One more step'), findsOneWidget);
      expect(find.text(stillMissing), findsOneWidget);
      expect(installer.installs, isEmpty);
    });

    testWidgets('opens the installer by itself once allowed', (tester) async {
      installer.allowed = false;
      await openUpdateBox(tester);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      installer.allowed = true;
      await returnFromSettings(tester);

      expect(find.text('Finish in the installer'), findsOneWidget);
      expect(installer.installs, [FakeAppUpdateInstaller.downloadedPath]);
    });

    testWidgets('explains a failed download and tries again', (tester) async {
      installer.downloadError = const AppUpdateInstallException(
        AppUpdateInstallFailure.downloadFailed,
        'offline',
      );
      await openUpdateBox(tester);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't update"), findsOneWidget);
      expect(
        find.text(
          'The download stopped. Check your internet connection and try again.',
        ),
        findsOneWidget,
      );

      installer.downloadError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Finish in the installer'), findsOneWidget);
    });

    testWidgets('explains an installer that could not open', (tester) async {
      installer.installError = const AppUpdateInstallException(
        AppUpdateInstallFailure.installFailed,
        'no installer',
      );
      await openUpdateBox(tester);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(
        find.text("Android's installer couldn't open. Try again."),
        findsOneWidget,
      );
    });
  });
}
