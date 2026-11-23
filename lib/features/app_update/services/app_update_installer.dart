import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Why downloading or installing an update failed.
enum AppUpdateInstallFailure { downloadFailed, installFailed }

/// Thrown when an update could not be downloaded or handed to the installer.
final class AppUpdateInstallException implements Exception {
  const AppUpdateInstallException(this.failure, this.message);

  final AppUpdateInstallFailure failure;
  final String message;

  @override
  String toString() => 'AppUpdateInstallException(${failure.name}): $message';
}

/// Thrown by [AppUpdateInstaller.download] when it was cancelled.
final class AppUpdateDownloadCancelled implements Exception {
  const AppUpdateDownloadCancelled();
}

/// Downloads a new version of the app and hands it to Android's installer.
abstract interface class AppUpdateInstaller {
  /// Downloads [url] into the app's updates folder and returns the file path.
  ///
  /// [onProgress] receives 0–1, or null when the size is unknown. Completing
  /// [cancel] stops the download and throws [AppUpdateDownloadCancelled].
  /// Throws [AppUpdateInstallException] when the download fails.
  Future<String> download(
    Uri url, {
    required void Function(double? progress) onProgress,
    Future<void>? cancel,
  });

  /// Whether the user has allowed this app to install apps.
  Future<bool> canInstall();

  /// Opens Android's "Install unknown apps" page for this app.
  Future<void> openInstallSettings();

  /// Opens Android's "Do you want to update this app?" screen for [path].
  /// Throws [AppUpdateInstallException] when the installer cannot open.
  Future<void> install(String path);

  /// Deletes downloaded updates (e.g. left over from an installed update).
  Future<void> clearDownloads();
}

/// Downloads with [http.Client] and talks to Android through the
/// `faunawatch/app_update` channel in `MainActivity.kt`.
final class AndroidAppUpdateInstaller implements AppUpdateInstaller {
  AndroidAppUpdateInstaller(this._client, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('faunawatch/app_update');

  static const fileName = 'faunawatch-update.apk';

  /// The download fails when no data arrives for this long.
  static const stallTimeout = Duration(seconds: 30);

  final http.Client _client;
  final MethodChannel _channel;

  Future<Directory> _updateDir() async {
    final path = await _channel.invokeMethod<String>('updateDir');
    if (path == null) throw StateError('No updates folder');
    return Directory(path);
  }

  @override
  Future<String> download(
    Uri url, {
    required void Function(double? progress) onProgress,
    Future<void>? cancel,
  }) async {
    final File target;
    final File partial;
    try {
      final dir = await _updateDir();
      target = File('${dir.path}${Platform.pathSeparator}$fileName');
      partial = File('${target.path}.part');
      for (final old in [target, partial]) {
        if (await old.exists()) await old.delete();
      }
    } catch (_) {
      throw const AppUpdateInstallException(
        AppUpdateInstallFailure.downloadFailed,
        'Could not prepare the updates folder.',
      );
    }

    IOSink? sink;
    StreamSubscription<List<int>>? subscription;
    final done = Completer<void>();
    // A cancel can fail [done] before anything awaits it.
    done.future.ignore();
    var cancelled = false;

    void fail(Object error) {
      if (!done.isCompleted) done.completeError(error);
    }

    unawaited(
      cancel?.then((_) {
        cancelled = true;
        unawaited(subscription?.cancel());
        fail(const AppUpdateDownloadCancelled());
      }),
    );

    try {
      final response = await _client
          .send(http.Request('GET', url))
          .timeout(stallTimeout);
      if (cancelled || response.statusCode != 200) {
        // Close the connection without reading the body.
        unawaited(response.stream.listen(null).cancel());
      }
      if (cancelled) throw const AppUpdateDownloadCancelled();
      if (response.statusCode != 200) {
        throw AppUpdateInstallException(
          AppUpdateInstallFailure.downloadFailed,
          'Download answered ${response.statusCode}.',
        );
      }

      final total = response.contentLength;
      var received = 0;
      final output = sink = partial.openWrite();
      onProgress(total == null || total <= 0 ? null : 0);
      subscription = response.stream
          .timeout(stallTimeout)
          .listen(
            (chunk) {
              output.add(chunk);
              received += chunk.length;
              if (total != null && total > 0) {
                onProgress((received / total).clamp(0, 1).toDouble());
              }
            },
            onError: fail,
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
      await done.future;
      await output.close();
      sink = null;
      if (total != null && total > 0 && received != total) {
        throw const AppUpdateInstallException(
          AppUpdateInstallFailure.downloadFailed,
          'The download stopped early.',
        );
      }
      await partial.rename(target.path);
      return target.path;
    } catch (error) {
      await subscription?.cancel();
      await sink?.close().catchError((_) {});
      if (await partial.exists()) await partial.delete();
      if (cancelled || error is AppUpdateDownloadCancelled) {
        throw const AppUpdateDownloadCancelled();
      }
      if (error is AppUpdateInstallException) rethrow;
      throw const AppUpdateInstallException(
        AppUpdateInstallFailure.downloadFailed,
        'The download failed.',
      );
    }
  }

  @override
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } catch (_) {
      // Nothing more to do: the user can still allow it from Android settings.
    }
  }

  @override
  Future<void> install(String path) async {
    try {
      await _channel.invokeMethod<void>('install', {'path': path});
    } catch (_) {
      throw const AppUpdateInstallException(
        AppUpdateInstallFailure.installFailed,
        'Could not open the installer.',
      );
    }
  }

  @override
  Future<void> clearDownloads() async {
    try {
      final dir = await _updateDir();
      if (!await dir.exists()) return;
      await for (final entry in dir.list()) {
        await entry.delete(recursive: true);
      }
    } catch (_) {
      // Leftovers live in the cache folder, which Android also clears.
    }
  }
}

final appUpdateInstallerProvider = Provider<AppUpdateInstaller>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AndroidAppUpdateInstaller(client);
});
