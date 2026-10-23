import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Presentation state for the welcome onboarding screen.
enum WelcomeStatus { idle, navigatingToLogin, navigatingToSignUp }

/// ViewModel managing user action events and state on the Welcome screen.
class WelcomeViewModel extends Notifier<WelcomeStatus> {
  @override
  WelcomeStatus build() {
    return WelcomeStatus.idle;
  }

  /// Triggers user intent to log in.
  void onLoginPressed() {
    state = WelcomeStatus.navigatingToLogin;
  }

  /// Triggers user intent to register.
  void onSignUpPressed() {
    state = WelcomeStatus.navigatingToSignUp;
  }

  /// Resets status back to idle after navigation handling.
  void resetStatus() {
    state = WelcomeStatus.idle;
  }
}

/// Provider exposing [WelcomeViewModel] and [WelcomeStatus].
final welcomeViewModelProvider =
    NotifierProvider<WelcomeViewModel, WelcomeStatus>(WelcomeViewModel.new);
