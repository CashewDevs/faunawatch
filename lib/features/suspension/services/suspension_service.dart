import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';

/// Contract for reading the signed-in user's suspension.
abstract interface class SuspensionService {
  /// The active suspension, or null when the user isn't suspended.
  Future<AccountSuspension?> fetchActive();

  /// Emits when the user may have been suspended or reactivated, and once
  /// the live connection is up (to catch anything missed while offline).
  Stream<void> watchChanges();
}

/// Reads `my_active_suspension()` and listens for the `account_suspended` /
/// `account_reactivated` notifications the database adds for this user.
///
/// The user can't read `user_sanctions` directly (it would reveal the
/// admin), so the notifications are the live signal.
class SupabaseSuspensionService implements SuspensionService {
  SupabaseSuspensionService(this._client);
  final SupabaseClient _client;
  static int _channelSequence = 0;

  /// Notification types that mean the suspension changed.
  static const changeTypes = {'account_suspended', 'account_reactivated'};

  @override
  Future<AccountSuspension?> fetchActive() async {
    final rows = await _client.rpc('my_active_suspension');
    if (rows is! List) return null;
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        final suspension = AccountSuspension.fromRow(row);
        if (suspension != null) return suspension;
      }
    }
    return null;
  }

  @override
  Stream<void> watchChanges() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('suspension:$userId:${_channelSequence++}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) {
                if (controller.isClosed) return;
                if (changeTypes.contains(payload.newRecord['type'])) {
                  controller.add(null);
                }
              },
            )
            .subscribe((status, _) {
              if (controller.isClosed) return;
              if (status == RealtimeSubscribeStatus.subscribed) {
                controller.add(null);
              }
            });
      },
      onCancel: () async {
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }
}

/// Used while signed out: never suspended, nothing to watch.
class SignedOutSuspensionService implements SuspensionService {
  const SignedOutSuspensionService();

  @override
  Future<AccountSuspension?> fetchActive() async => null;

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

/// Changes with the signed-in user, which rebuilds the ViewModel and drops
/// the previous user's suspension and subscription.
final suspensionServiceProvider = Provider<SuspensionService>((ref) {
  final userId = ref.watch(
    currentUserIdProvider.select((value) => value.valueOrNull),
  );
  if (userId == null) {
    return const SignedOutSuspensionService();
  }
  return SupabaseSuspensionService(ref.watch(supabaseClientProvider));
});
