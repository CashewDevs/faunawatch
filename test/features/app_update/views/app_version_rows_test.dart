import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
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
      ],
      child: const MaterialApp(home: Scaffold(body: AppVersionRows())),
    );
  }

  setUp(() {
    releases = FakeAppReleaseService();
    links = FakeExternalLinkService();
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
}
