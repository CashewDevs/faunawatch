import 'dart:async';

import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_release.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/models/update_reminder.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/app_update_installer.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:faunawatch/features/app_update/services/update_reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this device can install updates from GitHub. Only Android can:
/// iPhones only install apps from the App Store or TestFlight.
final selfUpdateSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// The time used by the automatic check (replaced in tests).
final appUpdateClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum UpdateCheckStatus { idle, checking, upToDate, available, failed }

/// Where installing the newer release has got to.
enum UpdateInstallStatus {
  /// Not started (or cancelled).
  idle,
  downloading,

  /// Downloaded, but the user must first allow FaunaWatch to install apps.
  needsPermission,

  /// Android's installer was opened; the user finishes there.
  installing,
  failed,
}

/// Presentation state for the app version and update rows in Settings.
class AppUpdateState {
  const AppUpdateState({
    this.installed,
    this.selfUpdateSupported = false,
    this.status = UpdateCheckStatus.idle,
    this.latest,
    this.installStatus = UpdateInstallStatus.idle,
    this.downloadProgress,
    this.downloadedPath,
    this.installFailure,
    this.permissionStillMissing = false,
    this.notice,
  });

  /// The installed version, or null while loading or when it is unknown.
  final AppVersion? installed;
  final bool selfUpdateSupported;
  final UpdateCheckStatus status;

  /// The newer release found by the last check (only when [status] is
  /// [UpdateCheckStatus.available]).
  final AppRelease? latest;

  final UpdateInstallStatus installStatus;

  /// 0–1 while downloading, or null when the size is unknown.
  final double? downloadProgress;

  /// The downloaded update, kept so it is not downloaded twice.
  final String? downloadedPath;

  /// Why the last download or install failed.
  final AppUpdateInstallFailure? installFailure;

  /// The permission was checked again (e.g. after a visit to Android
  /// settings) and is still not given.
  final bool permissionStillMissing;

  /// The newer version offered by the Feed banner, or null when the banner
  /// is hidden (nothing newer, or the user closed it for this version).
  final AppVersion? notice;

  /// Whether "Check for updates" is offered.
  bool get canCheck => selfUpdateSupported && installed != null;

  bool get isChecking => status == UpdateCheckStatus.checking;

  bool get isDownloading => installStatus == UpdateInstallStatus.downloading;

  /// Whether the newer release can be installed from inside the app (it has
  /// a `faunawatch.apk` attached).
  bool get canUpdateInApp => latest?.apkUrl != null;

  AppUpdateState copyWith({
    AppVersion? installed,
    UpdateCheckStatus? status,
    AppRelease? latest,
    bool clearLatest = false,
    UpdateInstallStatus? installStatus,
    double? downloadProgress,
    bool clearProgress = false,
    String? downloadedPath,
    AppUpdateInstallFailure? installFailure,
    bool clearInstallFailure = false,
    bool clearInstall = false,
    bool? permissionStillMissing,
    AppVersion? notice,
    bool clearNotice = false,
  }) {
    return AppUpdateState(
      notice: clearNotice ? null : notice ?? this.notice,
      installed: installed ?? this.installed,
      selfUpdateSupported: selfUpdateSupported,
      status: status ?? this.status,
      latest: clearLatest ? null : latest ?? this.latest,
      installStatus:
          installStatus ??
          (clearInstall ? UpdateInstallStatus.idle : this.installStatus),
      downloadProgress: clearInstall || clearProgress
          ? null
          : downloadProgress ?? this.downloadProgress,
      downloadedPath: clearInstall
          ? null
          : downloadedPath ?? this.downloadedPath,
      installFailure: clearInstall || clearInstallFailure
          ? null
          : installFailure ?? this.installFailure,
      // Only meaningful while the permission is being asked for.
      permissionStillMissing:
          !clearInstall &&
          (permissionStillMissing ??
              (installStatus == null && this.permissionStillMissing)),
    );
  }
}

/// Reads the installed version, checks GitHub for a newer release when asked,
/// and downloads and installs it. The result is kept for the app session.
class AppUpdateViewModel extends Notifier<AppUpdateState> {
  bool _disposed = false;

  /// Completed to cancel the running download; null when none is running.
  Completer<void>? _cancel;

  /// The installed version once read (null when unknown).
  late Future<AppVersion?> _installedLoaded;

  /// The automatic check runs once per app session.
  bool _autoChecked = false;

  AppUpdateInstaller get _installer => ref.read(appUpdateInstallerProvider);

  UpdateReminderService get _reminders =>
      ref.read(updateReminderServiceProvider);

  @override
  AppUpdateState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _cancel?.complete();
      _cancel = null;
    });
    final supported = ref.watch(selfUpdateSupportedProvider);
    _installedLoaded = _loadInstalled();
    // A finished update restarts the app, so a download left from an
    // earlier session is no longer needed.
    if (supported) unawaited(_installer.clearDownloads());
    return AppUpdateState(selfUpdateSupported: supported);
  }

  Future<AppVersion?> _loadInstalled() async {
    final installed = await ref.read(installedVersionServiceProvider).read();
    if (_disposed || installed == null) return null;
    state = state.copyWith(installed: installed);
    return installed;
  }

  /// The quiet check when the app opens: asks GitHub at most once every
  /// [UpdateReminder.checkInterval] (otherwise reuses the last answer) and
  /// shows the Feed banner for a newer version the user has not closed.
  /// Failures are silent; "Check for updates" in Settings still works.
  Future<void> autoCheck() async {
    if (_autoChecked || !state.selfUpdateSupported) return;
    _autoChecked = true;
    final installed = await _installedLoaded;
    if (_disposed || installed == null) return;

    var reminder = await _reminders.load();
    final now = ref.read(appUpdateClockProvider)();
    if (reminder.isDue(now)) {
      try {
        final latest = await ref.read(appReleaseServiceProvider).fetchLatest();
        if (_disposed) return;
        reminder = reminder.checkedAt(now, latest?.version);
        await _reminders.saveCheck(now, latest?.version);
        // Also let the Settings row show it, unless a check or update the
        // user started is already showing something.
        if (latest != null &&
            latest.version.isNewerThan(installed) &&
            state.status == UpdateCheckStatus.idle) {
          state = state.copyWith(
            status: UpdateCheckStatus.available,
            latest: latest,
          );
        }
      } on AppReleaseException {
        // Offline or GitHub busy: fall back to the last answer.
      }
    }
    if (_disposed) return;
    final notice = reminder.noticeFor(installed);
    if (notice != null) state = state.copyWith(notice: notice);
  }

  /// Hides the banner and does not show it again for this version.
  Future<void> dismissNotice() async {
    final notice = state.notice;
    if (notice == null) return;
    state = state.copyWith(clearNotice: true);
    await _reminders.saveDismissed(notice);
  }

  /// Makes sure the newer release's details are loaded for the "Update
  /// available" box (the banner may come from an earlier check). Returns
  /// whether there is a newer release to show.
  Future<bool> loadNewerRelease() async {
    if (state.status != UpdateCheckStatus.available || state.latest == null) {
      await checkForUpdates();
    }
    return state.status == UpdateCheckStatus.available && state.latest != null;
  }

  /// Asks GitHub for the newest release and compares it with [installed].
  /// Ignored while a check or download is running, or when checking is not
  /// offered.
  Future<void> checkForUpdates() async {
    final installed = state.installed;
    if (!state.canCheck ||
        state.isChecking ||
        state.isDownloading ||
        installed == null) {
      return;
    }
    state = state.copyWith(
      status: UpdateCheckStatus.checking,
      clearLatest: true,
      clearInstall: true,
    );

    final AppRelease? latest;
    try {
      latest = await ref.read(appReleaseServiceProvider).fetchLatest();
    } on AppReleaseException {
      if (!_disposed) {
        state = state.copyWith(status: UpdateCheckStatus.failed);
      }
      return;
    }
    if (_disposed) return;
    // A manual check counts for the automatic one too.
    unawaited(
      _reminders.saveCheck(ref.read(appUpdateClockProvider)(), latest?.version),
    );

    if (latest != null && latest.version.isNewerThan(installed)) {
      state = state.copyWith(
        status: UpdateCheckStatus.available,
        latest: latest,
      );
    } else {
      // Nothing newer after all: the banner's answer was out of date.
      state = state.copyWith(
        status: UpdateCheckStatus.upToDate,
        clearNotice: true,
      );
    }
  }

  /// Downloads the newer release (unless already downloaded) and opens
  /// Android's installer. Also used for "Try again".
  Future<void> startUpdate() async {
    final apkUrl = state.latest?.apkUrl;
    if (apkUrl == null || state.isDownloading) return;
    if (state.downloadedPath != null) return _install();

    final cancel = _cancel = Completer<void>();
    bool isCurrent() => !_disposed && identical(cancel, _cancel);
    state = state.copyWith(
      installStatus: UpdateInstallStatus.downloading,
      clearProgress: true,
      clearInstallFailure: true,
    );

    int? shownPercent;
    try {
      final path = await _installer.download(
        apkUrl,
        cancel: cancel.future,
        onProgress: (progress) {
          if (!isCurrent()) return;
          // Redraw only when the whole percentage changes.
          final percent = progress == null ? null : (progress * 100).floor();
          if (percent != null && percent == shownPercent) return;
          shownPercent = percent;
          state = progress == null
              ? state.copyWith(clearProgress: true)
              : state.copyWith(downloadProgress: progress);
        },
      );
      if (!isCurrent()) return;
      _cancel = null;
      state = state.copyWith(downloadedPath: path);
      await _install();
    } on AppUpdateDownloadCancelled {
      // cancelDownload already reset the state.
    } on AppUpdateInstallException catch (error) {
      if (!isCurrent()) return;
      _cancel = null;
      state = state.copyWith(
        installStatus: UpdateInstallStatus.failed,
        installFailure: error.failure,
        clearProgress: true,
      );
    }
  }

  /// Stops the running download.
  void cancelDownload() {
    final cancel = _cancel;
    if (cancel == null) return;
    _cancel = null;
    cancel.complete();
    state = state.copyWith(
      installStatus: UpdateInstallStatus.idle,
      clearProgress: true,
    );
  }

  /// Opens Android's page for allowing FaunaWatch to install apps.
  Future<void> openInstallSettings() => _installer.openInstallSettings();

  /// Opens the installer again for the downloaded update, e.g. after the
  /// user closed Android's installer.
  Future<void> installDownloaded() => _install();

  /// Checks the permission again while it is being asked for (called when
  /// the user comes back to the app, e.g. from Android settings): opens the
  /// installer when it was given, otherwise says it is still missing.
  Future<void> recheckInstallPermission() async {
    if (state.installStatus != UpdateInstallStatus.needsPermission) return;
    await _install();
  }

  Future<void> _install() async {
    final path = state.downloadedPath;
    if (path == null) return;
    if (!await _installer.canInstall()) {
      if (!_disposed) {
        state = state.copyWith(
          installStatus: UpdateInstallStatus.needsPermission,
          clearInstallFailure: true,
          // Asking a second time means the user went to settings and back.
          permissionStillMissing:
              state.installStatus == UpdateInstallStatus.needsPermission,
        );
      }
      return;
    }
    try {
      await _installer.install(path);
      if (_disposed) return;
      state = state.copyWith(
        installStatus: UpdateInstallStatus.installing,
        clearInstallFailure: true,
      );
    } on AppUpdateInstallException catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        installStatus: UpdateInstallStatus.failed,
        installFailure: error.failure,
      );
    }
  }

  /// Opens the newer release's GitHub page in the browser (for a release
  /// without `faunawatch.apk`). Returns false when there is no newer release
  /// or no app could open the page.
  Future<bool> openReleasePage() async {
    final latest = state.latest;
    if (latest == null) return false;
    return ref.read(externalLinkServiceProvider).open(latest.pageUrl);
  }
}

final appUpdateViewModelProvider =
    NotifierProvider<AppUpdateViewModel, AppUpdateState>(
      AppUpdateViewModel.new,
    );
