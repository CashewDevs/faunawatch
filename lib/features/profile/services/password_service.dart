import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

/// Contract for updating or resetting the signed-in user's password.
abstract interface class PasswordService {
  /// Re-authenticates with [currentPassword] and updates the user's password
  /// to [newPassword] while keeping the current session active.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Sends a password reset email to the currently signed-in user and returns
  /// the recipient email address.
  Future<String> sendPasswordResetEmail();
}

/// Supabase-backed implementation of [PasswordService].
class SupabasePasswordService implements PasswordService {
  const SupabasePasswordService(this._client);

  static const String _resetRedirectUrl =
      'com.faunawatch.app://login-callback/';

  final SupabaseClient _client;

  String _requireEmail() {
    final email = _client.auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'No email address is associated with this account.',
      );
    }
    return email;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _requireEmail();

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      throw const AuthException('Current password is incorrect.');
    }

    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<String> sendPasswordResetEmail() async {
    final email = _requireEmail();
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: _resetRedirectUrl,
    );
    return email;
  }
}

/// Riverpod provider exposing [PasswordService].
final passwordServiceProvider = Provider<PasswordService>((ref) {
  return SupabasePasswordService(ref.watch(supabaseClientProvider));
});
