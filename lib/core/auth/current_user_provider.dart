import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

/// Reactively exposes the ID of the currently signed-in Supabase user.
///
/// Emits `null` when no session is active. Rebuilds automatically on
/// sign-in, sign-out, and session refresh — no manual updates needed.
final currentUserIdProvider = StreamProvider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session?.user.id);
});
