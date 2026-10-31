import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

void main() {
  group('ShellViewModel', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial destination is feed', () {
      final destination = container.read(shellViewModelProvider);
      expect(destination, equals(ShellDestination.feed));
    });

    test('selectDestination updates destination correctly', () {
      final viewModel = container.read(shellViewModelProvider.notifier);

      for (final destination in ShellDestination.values.reversed) {
        viewModel.selectDestination(destination);
        expect(container.read(shellViewModelProvider), equals(destination));
      }
    });

    test('destinations match the navigation bar order', () {
      expect(ShellDestination.values, [
        ShellDestination.feed,
        ShellDestination.chats,
        ShellDestination.addPost,
        ShellDestination.notifs,
        ShellDestination.profile,
      ]);
    });

    test('selectIndex updates destination by valid index', () {
      final viewModel = container.read(shellViewModelProvider.notifier);

      for (var i = ShellDestination.values.length - 1; i >= 0; i--) {
        viewModel.selectIndex(i);
        expect(
          container.read(shellViewModelProvider),
          equals(ShellDestination.values[i]),
        );
      }
    });

    test('selectIndex ignores out-of-bounds indices', () {
      final viewModel = container.read(shellViewModelProvider.notifier);

      // Default is feed
      viewModel.selectIndex(-1);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.feed),
      );

      viewModel.selectIndex(ShellDestination.values.length);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.feed),
      );

      viewModel.selectIndex(99);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.feed),
      );
    });
  });
}
