import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State representing splash screen initialization.
enum SplashState { initializing, complete }

/// ViewModel managing splash screen initialization delay and readiness.
class SplashViewModel extends Notifier<SplashState> {
  @override
  SplashState build() {
    return SplashState.initializing;
  }

  /// Initiates splash screen timer and marks initialization complete.
  Future<void> initializeApp({
    Duration delay = const Duration(milliseconds: 1500),
  }) async {
    await Future<void>.delayed(delay);
    state = SplashState.complete;
  }
}

/// Provider exposing [SplashViewModel] and [SplashState].
final splashViewModelProvider = NotifierProvider<SplashViewModel, SplashState>(
  SplashViewModel.new,
);
