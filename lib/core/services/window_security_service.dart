import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service that controls the platform FLAG_SECURE window flag.
///
/// On Android this prevents screenshots, screen recording, and the recents
/// thumbnail while the flag is active. On unsupported platforms the calls
/// are silently ignored.
abstract interface class WindowSecurityService {
  /// Enables FLAG_SECURE, blocking screenshots and the recents thumbnail.
  Future<void> enableSecure();

  /// Clears FLAG_SECURE, restoring normal screenshot behavior.
  Future<void> disableSecure();
}

/// Default implementation that delegates to the Android platform channel
/// registered in `MainActivity.kt`.
final class PlatformWindowSecurityService implements WindowSecurityService {
  PlatformWindowSecurityService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('faunawatch/window_security');

  final MethodChannel _channel;

  @override
  Future<void> enableSecure() => _setSecure(true);

  @override
  Future<void> disableSecure() => _setSecure(false);

  Future<void> _setSecure(bool secure) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } catch (_) {
      // Ignore when window security flag is unavailable (e.g. in tests).
    }
  }
}

/// Riverpod provider exposing the [WindowSecurityService].
final windowSecurityServiceProvider = Provider<WindowSecurityService>(
  (ref) => PlatformWindowSecurityService(),
);
