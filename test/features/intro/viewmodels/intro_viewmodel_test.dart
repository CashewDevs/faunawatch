import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/intro/viewmodels/intro_viewmodel.dart';

void main() {
  group('IntroViewModel', () {
    test('initial state is IntroStatus.ready', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(introViewModelProvider);
      expect(state, IntroStatus.ready);
    });

    test('onSlideUp transitions state to IntroStatus.proceeding', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(introViewModelProvider.notifier).onSlideUp();
      final state = container.read(introViewModelProvider);
      expect(state, IntroStatus.proceeding);
    });
  });
}
