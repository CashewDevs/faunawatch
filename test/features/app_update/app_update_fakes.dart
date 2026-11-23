import 'dart:async';

import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_release.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/app_update_installer.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:faunawatch/features/app_update/services/update_reminder_service.dart';
import 'package:faunawatch/features/app_update/models/update_reminder.dart';

class FakeInstalledVersionService implements InstalledVersionService {
  FakeInstalledVersionService(this.version);

  final AppVersion? version;

  @override
  Future<AppVersion?> read() async => version;
}

class FakeAppReleaseService implements AppReleaseService {
  FakeAppReleaseService({this.release, this.error});

  AppRelease? release;
  AppReleaseException? error;
  int calls = 0;

  /// When set, [fetchLatest] waits for it before answering.
  Completer<void>? gate;

  @override
  Future<AppRelease?> fetchLatest() async {
    calls++;
    await gate?.future;
    if (error case final error?) throw error;
    return release;
  }
}

class FakeExternalLinkService implements ExternalLinkService {
  FakeExternalLinkService({this.result = true});

  final bool result;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

class FakeAppUpdateInstaller implements AppUpdateInstaller {
  static const downloadedPath = '/cache/updates/faunawatch-update.apk';

  /// Progress reported by every download before it waits on [gate].
  List<double?> progressSteps = [0.25, 0.5];

  /// When set, downloads wait for it (or a cancel) before finishing.
  Completer<void>? gate;

  bool allowed = true;
  AppUpdateInstallException? downloadError;
  AppUpdateInstallException? installError;

  final List<Uri> downloads = [];
  final List<String> installs = [];
  int settingsOpened = 0;
  int clears = 0;

  @override
  Future<String> download(
    Uri url, {
    required void Function(double? progress) onProgress,
    Future<void>? cancel,
  }) async {
    downloads.add(url);
    progressSteps.forEach(onProgress);
    if (gate case final gate?) {
      await Future.any([
        gate.future,
        if (cancel != null)
          cancel.then<void>((_) => throw const AppUpdateDownloadCancelled()),
      ]);
    }
    if (downloadError case final error?) throw error;
    return downloadedPath;
  }

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<void> install(String path) async {
    if (installError case final error?) throw error;
    installs.add(path);
  }

  @override
  Future<void> clearDownloads() async => clears++;
}

final testApkUrl = Uri.parse(
  'https://github.com/CashewDevs/faunawatch/releases/download/v1.0.1+3/faunawatch.apk',
);

AppRelease testRelease({
  AppVersion version = const AppVersion(1, 0, 1, build: 3),
  String? notes = 'Faster map.',
  Uri? apkUrl,
}) => AppRelease(
  version: version,
  pageUrl: Uri.parse(
    'https://github.com/CashewDevs/faunawatch/releases/tag/v1.0.1+3',
  ),
  notes: notes,
  apkUrl: apkUrl,
);

class FakeUpdateReminderService implements UpdateReminderService {
  FakeUpdateReminderService([this.reminder = const UpdateReminder()]);

  UpdateReminder reminder;
  final List<AppVersion> dismissedSaves = [];
  int checkSaves = 0;

  @override
  Future<UpdateReminder> load() async => reminder;

  @override
  Future<void> saveCheck(DateTime time, AppVersion? found) async {
    checkSaves++;
    reminder = reminder.checkedAt(time, found);
  }

  @override
  Future<void> saveDismissed(AppVersion version) async {
    dismissedSaves.add(version);
    reminder = UpdateReminder(
      lastCheckedAt: reminder.lastCheckedAt,
      lastFound: reminder.lastFound,
      dismissed: version,
    );
  }
}
