import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/models/auth_session_profile.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

abstract interface class GoogleAuthService {
  Stream<void> get signedIn;
  Future<bool> launchSignIn();
  Future<AuthSessionProfile?> loadSessionProfile();
}

/// Uses Supabase's PKCE flow and built-in app_links callback handling.
class SupabaseGoogleAuthService implements GoogleAuthService {
  const SupabaseGoogleAuthService(this._client);

  static const redirectUrl = 'com.faunawatch.app://login-callback/';
  final SupabaseClient _client;

  @override
  Stream<void> get signedIn => _client.auth.onAuthStateChange
      .where((event) => event.event == AuthChangeEvent.signedIn)
      .map((_) {});

  @override
  Future<bool> launchSignIn() => _client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: redirectUrl,
    authScreenLaunchMode: LaunchMode.externalApplication,
    queryParams: const {'prompt': 'select_account'},
  );

  @override
  Future<AuthSessionProfile?> loadSessionProfile() async {
    final userId = _client.auth.currentSession?.user.id;
    if (userId == null) return null;
    final profile = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', userId)
        .single();
    // Never route a stale result after sign-out or an account switch.
    if (_client.auth.currentSession?.user.id != userId) {
      return null;
    }
    return AuthSessionProfile(
      userId: userId,
      displayName: profile['display_name'] as String?,
    );
  }
}

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return SupabaseGoogleAuthService(ref.watch(supabaseClientProvider));
});
