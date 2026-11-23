import 'dart:async';

import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/features/app_update/models/app_release.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';

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

AppRelease testRelease({
  AppVersion version = const AppVersion(1, 0, 1, build: 3),
  String? notes = 'Faster map.',
}) => AppRelease(
  version: version,
  pageUrl: Uri.parse(
    'https://github.com/CashewDevs/faunawatch/releases/tag/v1.0.1+3',
  ),
  notes: notes,
);
