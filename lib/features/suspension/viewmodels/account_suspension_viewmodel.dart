import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/services/suspension_service.dart';

/// The current time, injectable so tests can control when a suspension ends.
final suspensionClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The signed-in user's active suspension, or null when they aren't
/// suspended (or nobody is signed in).
///
/// Checks on sign-in, when the database notifies a suspension or
/// reactivation, when the suspension's end time passes, and whenever
/// [refresh] is called (the app calls it on resume). A failed check keeps
/// what was known: the database blocks a suspended user's posts either way.
class AccountSuspensionViewModel extends Notifier<AccountSuspension?> {
  /// Longest wait before re-checking an ending suspension. Long timers are
  /// unreliable on some platforms (web caps them at about 24 days).
  static const maxEndWait = Duration(hours: 12);

  /// Wait when the end has passed but the database still says suspended
  /// (e.g. the phone's clock is ahead).
  static const pastEndRetry = Duration(seconds: 30);

  late SuspensionService _service;
  int _generation = 0;
  Timer? _endTimer;

  @override
  AccountSuspension? build() {
    _service = ref.watch(suspensionServiceProvider);
    final generation = ++_generation;
    StreamSubscription<void>? subscription;
    ref.onDispose(() {
      _generation++;
      subscription?.cancel();
      _endTimer?.cancel();
    });
    Future.microtask(() {
      if (generation != _generation) return;
      subscription = _service.watchChanges().listen(
        (_) => refresh(),
        // A dropped connection is caught up by the next resume or sign-in.
        onError: (_) {},
      );
      refresh();
    });
    return null;
  }

  /// Asks the database again.
  Future<void> refresh() async {
    final generation = _generation;
    final AccountSuspension? suspension;
    try {
      suspension = await _service.fetchActive();
    } catch (_) {
      return;
    }
    if (generation != _generation) return;
    if (suspension != state) state = suspension;
    _scheduleEndCheck(suspension);
  }

  void _scheduleEndCheck(AccountSuspension? suspension) {
    _endTimer?.cancel();
    _endTimer = null;
    final end = suspension?.endsAt;
    if (end == null) return;
    var wait =
        end.difference(ref.read(suspensionClockProvider)()) +
        const Duration(seconds: 1);
    if (wait <= Duration.zero) wait = pastEndRetry;
    if (wait > maxEndWait) wait = maxEndWait;
    _endTimer = Timer(wait, refresh);
  }

  /// Really signs out of Supabase (the suspension screen's only action).
  /// Returns false when it failed.
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

/// Provider exposing [AccountSuspensionViewModel].
final accountSuspensionViewModelProvider =
    NotifierProvider<AccountSuspensionViewModel, AccountSuspension?>(
      AccountSuspensionViewModel.new,
    );
