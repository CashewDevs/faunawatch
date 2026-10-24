import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/onboarding/viewmodels/onboarding_viewmodel.dart';

void main() {
  group('OnboardingViewModel', () {
    test('initial state defaults to page 0 and is not last page', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(onboardingViewModelProvider);
      expect(state.currentPage, 0);
      expect(state.totalPages, 3);
      expect(state.isLastPage, false);
    });

    test('onPageChanged updates currentPage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(onboardingViewModelProvider.notifier).onPageChanged(1);
      final state = container.read(onboardingViewModelProvider);
      expect(state.currentPage, 1);
      expect(state.isLastPage, false);
    });

    test('nextPage advances page until last page is reached', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingViewModelProvider.notifier);

      notifier.nextPage();
      expect(container.read(onboardingViewModelProvider).currentPage, 1);
      expect(container.read(onboardingViewModelProvider).isLastPage, false);

      notifier.nextPage();
      expect(container.read(onboardingViewModelProvider).currentPage, 2);
      expect(container.read(onboardingViewModelProvider).isLastPage, true);

      // Does not exceed last page
      notifier.nextPage();
      expect(container.read(onboardingViewModelProvider).currentPage, 2);
      expect(container.read(onboardingViewModelProvider).isLastPage, true);
    });
  });
}
