import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the initialized [SupabaseClient] singleton.
///
/// All services that need Supabase access should read this provider rather
/// than calling [Supabase.instance.client] directly — it keeps dependencies
/// explicit and testable.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Contract for authentication operations.
abstract interface class AuthService {
  /// Signs in a user with email and password.
  Future<bool> login(String email, String password);

  /// Registers a new user with email and password.
  Future<bool> signUp(String email, String password);

  /// Signs out the currently authenticated user.
  Future<void> signOut();
}

/// Supabase-backed implementation of [AuthService].
class SupabaseAuthService implements AuthService {
  const SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return response.user != null;
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    if (response.user != null &&
        response.user!.identities != null &&
        response.user!.identities!.isEmpty) {
      throw const AuthException(
        'This email is already registered. Please log in instead.',
      );
    }
    // A non-null user means the account was created (or email confirmation
    // is pending — the app should handle both cases via auth state stream).
    return response.user != null;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

/// Riverpod provider exposing [AuthService].
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthService(client);
});
