import 'dart:async';

import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_release.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this device can install updates from GitHub. Only Android can:
/// iPhones only install apps from the App Store or TestFlight.
final selfUpdateSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

enum UpdateCheckStatus { idle, checking, upToDate, available, failed }

/// Presentation state for the app version and update rows in Settings.
class AppUpdateState {
  const AppUpdateState({
    this.installed,
    this.selfUpdateSupported = false,
    this.status = UpdateCheckStatus.idle,
    this.latest,
  });

  /// The installed version, or null while loading or when it is unknown.
  final AppVersion? installed;
  final bool selfUpdateSupported;
  final UpdateCheckStatus status;

  /// The newer release found by the last check (only when [status] is
  /// [UpdateCheckStatus.available]).
  final AppRelease? latest;

  /// Whether "Check for updates" is offered.
  bool get canCheck => selfUpdateSupported && installed != null;

  bool get isChecking => status == UpdateCheckStatus.checking;

  AppUpdateState copyWith({
    AppVersion? installed,
    UpdateCheckStatus? status,
    AppRelease? latest,
    bool clearLatest = false,
  }) {
    return AppUpdateState(
      installed: installed ?? this.installed,
      selfUpdateSupported: selfUpdateSupported,
      status: status ?? this.status,
      latest: clearLatest ? null : latest ?? this.latest,
    );
  }
}

/// Reads the installed version and checks GitHub for a newer release when
/// asked. The result is kept for the app session.
class AppUpdateViewModel extends Notifier<AppUpdateState> {
  bool _disposed = false;

  @override
  AppUpdateState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    unawaited(_loadInstalled());
    return AppUpdateState(
      selfUpdateSupported: ref.watch(selfUpdateSupportedProvider),
    );
  }

  Future<void> _loadInstalled() async {
    final installed = await ref.read(installedVersionServiceProvider).read();
    if (_disposed || installed == null) return;
    state = state.copyWith(installed: installed);
  }

  /// Asks GitHub for the newest release and compares it with [installed].
  /// Ignored while a check is running or when checking is not offered.
  Future<void> checkForUpdates() async {
    final installed = state.installed;
    if (!state.canCheck || state.isChecking || installed == null) return;
    state = state.copyWith(
      status: UpdateCheckStatus.checking,
      clearLatest: true,
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

    if (latest != null && latest.version.isNewerThan(installed)) {
      state = state.copyWith(
        status: UpdateCheckStatus.available,
        latest: latest,
      );
    } else {
      state = state.copyWith(status: UpdateCheckStatus.upToDate);
    }
  }

  /// Opens the newer release's GitHub page in the browser. Returns false when
  /// there is no newer release or no app could open the page.
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
