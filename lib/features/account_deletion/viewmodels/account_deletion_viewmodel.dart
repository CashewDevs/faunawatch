import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';
import 'package:faunawatch/features/account_deletion/services/account_deletion_service.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

/// The current time, injectable so tests can control when the date passes.
final accountDeletionClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// What happened after "Delete account".
class AccountDeletionRequestResult {
  const AccountDeletionRequestResult({
    required this.deletion,
    required this.signedOut,
  });

  final AccountDeletion deletion;

  /// False when signing out failed (e.g. offline). The account is still
  /// scheduled, so the "Keep my account" screen takes over instead.
  final bool signedOut;
}

/// The signed-in user's waiting account deletion, or null.
///
/// Checks on sign-in and whenever [refresh] is called (the app calls it on
/// resume). While it isn't null, the app shows only the "Keep my account"
/// screen. A failed check keeps what was known.
class AccountDeletionViewModel extends Notifier<AccountDeletion?> {
  late AccountDeletionService _service;
  int _generation = 0;

  @override
  AccountDeletion? build() {
    _service = ref.watch(accountDeletionServiceProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    Future.microtask(() {
      if (generation == _generation) refresh();
    });
    return null;
  }

  /// Asks the database again.
  Future<void> refresh() async {
    final generation = _generation;
    final AccountDeletion? deletion;
    try {
      deletion = await _service.fetchScheduled();
    } catch (_) {
      return;
    }
    if (generation != _generation) return;
    if (deletion != state) state = deletion;
  }

  /// True when the waiting deletion's date has passed.
  bool isDue(AccountDeletion deletion) =>
      deletion.isDue(ref.read(accountDeletionClockProvider)());

  /// "Delete account": schedules the deletion, removes this phone's saved AI
  /// keys, and signs out on every device. Throws [AccountDeletionException]
  /// when the deletion couldn't be scheduled (nothing else is done then).
  Future<AccountDeletionRequestResult> requestDeletion(
    String confirmation,
  ) async {
    if (!isDeleteConfirmation(confirmation)) {
      throw const AccountDeletionException(AccountDeletionFailure.notConfirmed);
    }
    // Read now: they change once the session ends.
    final service = _service;
    final userId = ref.read(currentUserIdProvider).valueOrNull;

    final deletion = await service.request(confirmation);

    // The account is scheduled; the rest is best effort.
    if (userId != null) {
      try {
        await ref.read(aiApiKeyStorageServiceProvider).deleteAllKeys(userId);
      } catch (_) {
        /* The keys are stored per user; nobody else can read them. */
      }
    }
    final push = ref.read(pushViewModelProvider.notifier);
    // The database already removed every push token of the account; this
    // also forgets this phone's.
    await push.onBeforeSignOut();
    try {
      await service.signOutEverywhere();
    } catch (_) {
      // Still signed in: show the "Keep my account" screen.
      state = deletion;
      return AccountDeletionRequestResult(deletion: deletion, signedOut: false);
    }
    ref.read(shellViewModelProvider.notifier).resetToHome();
    return AccountDeletionRequestResult(deletion: deletion, signedOut: true);
  }

  /// "Keep my account": cancels the deletion. Throws
  /// [AccountDeletionException], e.g. [AccountDeletionFailure.tooLate].
  Future<void> keepAccount() async {
    final generation = _generation;
    await _service.cancel();
    if (generation == _generation) state = null;
  }

  /// Really signs out of Supabase (the screen's other action). Returns false
  /// when it failed.
  Future<bool> signOut() async {
    final push = ref.read(pushViewModelProvider.notifier);
    // The push token is removed first, while the session can still call the
    // database.
    await push.onBeforeSignOut();
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {
      await push.onSignOutFailed();
      return false;
    }
    ref.read(shellViewModelProvider.notifier).resetToHome();
    return true;
  }
}

/// Provider exposing [AccountDeletionViewModel].
final accountDeletionViewModelProvider =
    NotifierProvider<AccountDeletionViewModel, AccountDeletion?>(
      AccountDeletionViewModel.new,
    );
