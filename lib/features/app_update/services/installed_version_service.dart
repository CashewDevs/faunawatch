import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the version of the app installed on this device.
abstract interface class InstalledVersionService {
  /// The installed version, or null when it cannot be read on this platform.
  Future<AppVersion?> read();
}

/// Asks Android for the installed version through the `faunawatch/app_info`
/// channel registered in `MainActivity.kt`.
///
/// Other platforms return null: the version comes from native code, and the
/// `package_info_plus` package cannot be used in this project (see AGENTS.md).
final class PlatformInstalledVersionService implements InstalledVersionService {
  PlatformInstalledVersionService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('faunawatch/app_info');

  final MethodChannel _channel;

  @override
  Future<AppVersion?> read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final info = await _channel.invokeMapMethod<String, Object?>(
        'getVersion',
      );
      final name = info?['versionName'];
      final code = info?['versionCode'];
      if (name is! String) return null;
      final version = AppVersion.tryParse(name);
      if (version == null) return null;
      return AppVersion(
        version.major,
        version.minor,
        version.patch,
        build: code is int ? code : version.build,
      );
    } catch (_) {
      // Missing channel (e.g. in tests) or a platform error.
      return null;
    }
  }
}

final installedVersionServiceProvider = Provider<InstalledVersionService>(
  (ref) => PlatformInstalledVersionService(),
);
