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

  /// Initiates splash screen timer and marks initialization complete.
  Future<void> initializeApp({
    Duration delay = const Duration(milliseconds: 1500),
  }) async {
    if (state == SplashState.failed) state = SplashState.initializing;
    await Future<void>.delayed(delay);
    try {
      final profile = await ref
          .read(googleAuthServiceProvider)
          .loadSessionProfile();
      state = profile == null
          ? SplashState.complete
          : profile.hasDisplayName
          ? SplashState.home
          : SplashState.profileSetup;
    } catch (_) {
      state = SplashState.failed;
    }
  }
}

/// Provider exposing [SplashViewModel] and [SplashState].
final splashViewModelProvider = NotifierProvider<SplashViewModel, SplashState>(
  SplashViewModel.new,
);
