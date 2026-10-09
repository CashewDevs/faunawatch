import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the ID of the currently signed-in Supabase user.
///
/// Returns `null` when no user is signed in.
/// Can be updated reactively on sign-in, user switch, or sign-out.
final currentUserIdProvider = StateProvider<String?>((ref) => null);
