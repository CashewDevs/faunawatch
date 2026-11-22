import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/auth/services/google_auth_service.dart';

/// State representing splash screen initialization.
enum SplashState { initializing, complete, home, profileSetup, failed }

/// Resolves the restored session and profile before leaving the splash screen.
class SplashViewModel extends Notifier<SplashState> {
  @override
  SplashState build() {
    return SplashState.initializing;
  }

  /// Checks whether someone is signed in while the splash animation plays.
  ///
  /// The check starts at once; the result is published only when the check
  /// AND [introFinished] (the end of the splash animation) are both done, so
  /// the screen never leaves halfway through the animation and never waits
  /// longer than the slower of the two. Without [introFinished] (e.g. Retry,
  /// after the animation already ran) only the check is awaited.
  Future<void> initializeApp({Future<void>? introFinished}) async {
    if (state == SplashState.failed) state = SplashState.initializing;
    final destination = _resolveDestination();
    if (introFinished != null) await introFinished;
    state = await destination;
  }

  /// Where to go next; a failure becomes [SplashState.failed], never an error.
  Future<SplashState> _resolveDestination() async {
    try {
      final profile = await ref
          .read(googleAuthServiceProvider)
          .loadSessionProfile();
      return profile == null
          ? SplashState.complete
          : profile.hasDisplayName
          ? SplashState.home
          : SplashState.profileSetup;
    } catch (_) {
      return SplashState.failed;
    }
  }
}

/// Provider exposing [SplashViewModel] and [SplashState].
final splashViewModelProvider = NotifierProvider<SplashViewModel, SplashState>(
  SplashViewModel.new,
);
