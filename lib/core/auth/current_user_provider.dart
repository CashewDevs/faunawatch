import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the ID of the currently signed-in Supabase user.
///
/// Returns `null` when no user is signed in.
/// Can be updated reactively on sign-in, user switch, or sign-out.
// TODO(auth): Nothing in lib/ currently writes to this provider, so key
// operations will fail with "User must be signed in" until the auth feature
// sets it on sign-in. Wire this up when Supabase auth integration lands.
final currentUserIdProvider = StateProvider<String?>((ref) => null);
