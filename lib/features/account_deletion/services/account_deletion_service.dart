import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

/// Contract for scheduling, checking and cancelling the signed-in user's
/// account deletion.
abstract interface class AccountDeletionService {
  /// The waiting deletion, or null when the account isn't waiting.
  Future<AccountDeletion?> fetchScheduled();

  /// Schedules the deletion and returns it. Throws
  /// [AccountDeletionException].
  Future<AccountDeletion> request(String confirmation);

  /// Cancels the waiting deletion. False when nothing was waiting. Throws
  /// [AccountDeletionException] ([AccountDeletionFailure.tooLate] once the
  /// date has passed).
  Future<bool> cancel();

  /// Ends every session of this account, on all devices. Throws only when
  /// this device is still signed in afterwards.
  Future<void> signOutEverywhere();
}

/// Calls `request_account_deletion()`, `my_account_deletion()` and
/// `cancel_account_deletion()`.
class SupabaseAccountDeletionService implements AccountDeletionService {
  const SupabaseAccountDeletionService(this._client);
  final SupabaseClient _client;

  @override
  Future<AccountDeletion?> fetchScheduled() async {
    final value = await _client.rpc('my_account_deletion');
    return _deletion(value);
  }

  @override
  Future<AccountDeletion> request(String confirmation) async {
    final Object? value;
    try {
      value = await _client.rpc(
        'request_account_deletion',
        params: {'p_confirmation': confirmation},
      );
    } catch (error) {
      throw AccountDeletionException(_failure(error));
    }
    final deletion = _deletion(value);
    if (deletion == null) {
      throw const AccountDeletionException(AccountDeletionFailure.unknown);
    }
    return deletion;
  }

  @override
  Future<bool> cancel() async {
    try {
      return await _client.rpc('cancel_account_deletion') == true;
    } catch (error) {
      throw AccountDeletionException(_failure(error));
    }
  }

  @override
  Future<void> signOutEverywhere() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.global);
    } catch (_) {
      // Like AuthService.signOut: this device is signed out first, so only a
      // session still here counts as a failure.
      if (_client.auth.currentSession != null) rethrow;
    }
  }

  static AccountDeletion? _deletion(Object? value) {
    if (value == null) return null;
    final date = DateTime.tryParse('$value');
    return date == null ? null : AccountDeletion(deleteAfter: date.toLocal());
  }

  /// Error codes set by the database functions.
  static AccountDeletionFailure _failure(Object error) {
    if (error is! PostgrestException) return AccountDeletionFailure.unknown;
    return switch (error.code) {
      '22023' => AccountDeletionFailure.notConfirmed,
      '42501' when error.message.contains('Admin') =>
        AccountDeletionFailure.adminAccount,
      'P0001' => AccountDeletionFailure.tooLate,
      _ => AccountDeletionFailure.unknown,
    };
  }
}

/// Used while signed out: nothing is waiting and nothing can be changed.
class SignedOutAccountDeletionService implements AccountDeletionService {
  const SignedOutAccountDeletionService();

  @override
  Future<AccountDeletion?> fetchScheduled() async => null;

  @override
  Future<AccountDeletion> request(String confirmation) => Future.error(
    const AccountDeletionException(AccountDeletionFailure.unknown),
  );

  @override
  Future<bool> cancel() async => false;

  @override
  Future<void> signOutEverywhere() async {}
}

/// Changes with the signed-in user, which rebuilds the ViewModel and drops
/// the previous user's state.
final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  final userId = ref.watch(
    currentUserIdProvider.select((value) => value.valueOrNull),
  );
  if (userId == null) return const SignedOutAccountDeletionService();
  return SupabaseAccountDeletionService(ref.watch(supabaseClientProvider));
});
