import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the onboarding walkthrough flow.
class OnboardingState {
  const OnboardingState({this.currentPage = 0, this.totalPages = 3});

  final int currentPage;
  final int totalPages;

  bool get isLastPage => currentPage >= totalPages - 1;

  OnboardingState copyWith({int? currentPage, int? totalPages}) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

/// ViewModel managing page navigation and completion in onboarding walkthrough.
class OnboardingViewModel extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    return const OnboardingState();
  }

  void onPageChanged(int index) {
    state = state.copyWith(currentPage: index);
  }

  void nextPage() {
    if (state.currentPage < state.totalPages - 1) {
      state = state.copyWith(currentPage: state.currentPage + 1);
    }
  }
}

/// Provider exposing [OnboardingViewModel] and [OnboardingState].
final onboardingViewModelProvider =
    NotifierProvider<OnboardingViewModel, OnboardingState>(
      OnboardingViewModel.new,
    );
