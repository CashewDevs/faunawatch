import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Presentation state for the intro / slide-up landing screen.
enum IntroStatus { ready, proceeding }

/// ViewModel managing presentation state and navigation readiness for the Intro screen.
class IntroViewModel extends Notifier<IntroStatus> {
  @override
  IntroStatus build() {
    return IntroStatus.ready;
  }

  /// Triggered when the user initiates the slide up gesture or taps the slide up button.
  void onSlideUp() {
    state = IntroStatus.proceeding;
  }
}

/// Provider exposing [IntroViewModel] and [IntroStatus].
final introViewModelProvider = NotifierProvider<IntroViewModel, IntroStatus>(
  IntroViewModel.new,
);
