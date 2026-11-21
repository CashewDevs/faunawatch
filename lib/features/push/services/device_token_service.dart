import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

/// Contract for storing this device's push token for the signed-in user.
abstract interface class DeviceTokenService {
  /// Saves [token] for the signed-in user. A token already saved for another
  /// account is reassigned (the device switched accounts).
  Future<void> register(String token, String platform);

  /// Removes [token] if the signed-in user owns it.
  Future<void> unregister(String token);
}

/// Calls the `register_device_token` / `unregister_device_token` RPCs.
class SupabaseDeviceTokenService implements DeviceTokenService {
  SupabaseDeviceTokenService(this._client);
  final SupabaseClient _client;

  @override
  Future<void> register(String token, String platform) async {
    await _client.rpc<void>(
      'register_device_token',
      params: {'p_token': token, 'p_platform': platform},
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _client.rpc<void>(
      'unregister_device_token',
      params: {'p_token': token},
    );
  }
}

/// Provider exposing [DeviceTokenService].
final deviceTokenServiceProvider = Provider<DeviceTokenService>(
  (ref) => SupabaseDeviceTokenService(ref.watch(supabaseClientProvider)),
);
