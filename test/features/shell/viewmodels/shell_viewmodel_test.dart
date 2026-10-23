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

      viewModel.selectDestination(ShellDestination.gallery);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.gallery),
      );

      viewModel.selectDestination(ShellDestination.map);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.map),
      );

      viewModel.selectDestination(ShellDestination.chats);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.chats),
      );

      viewModel.selectDestination(ShellDestination.notifs);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.notifs),
      );

      viewModel.selectDestination(ShellDestination.profile);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.profile),
      );

      viewModel.selectDestination(ShellDestination.feed);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.feed),
      );
    });

    test('selectIndex updates destination by valid index', () {
      final viewModel = container.read(shellViewModelProvider.notifier);

      viewModel.selectIndex(1);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.gallery),
      );

      viewModel.selectIndex(2);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.map),
      );

      viewModel.selectIndex(3);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.chats),
      );

      viewModel.selectIndex(4);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.notifs),
      );

      viewModel.selectIndex(5);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.profile),
      );

      viewModel.selectIndex(0);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.feed),
      );
    });

    test('selectIndex ignores out-of-bounds indices', () {
      final viewModel = container.read(shellViewModelProvider.notifier);

      // Default is feed
      viewModel.selectIndex(-1);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.feed),
      );

      viewModel.selectIndex(6);
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
