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

    test('initial destination is report', () {
      final destination = container.read(shellViewModelProvider);
      expect(destination, equals(ShellDestination.report));
    });

    test('selectDestination updates destination correctly', () {
      final viewModel = container.read(shellViewModelProvider.notifier);

      viewModel.selectDestination(ShellDestination.map);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.map),
      );

      viewModel.selectDestination(ShellDestination.alerts);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.alerts),
      );

      viewModel.selectDestination(ShellDestination.profile);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.profile),
      );

      viewModel.selectDestination(ShellDestination.report);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.report),
      );
    });

    test('selectIndex updates destination by valid index', () {
      final viewModel = container.read(shellViewModelProvider.notifier);

      viewModel.selectIndex(1);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.map),
      );

      viewModel.selectIndex(2);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.alerts),
      );

      viewModel.selectIndex(3);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.profile),
      );

      viewModel.selectIndex(0);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.report),
      );
    });

    test('selectIndex ignores out-of-bounds indices', () {
      final viewModel = container.read(shellViewModelProvider.notifier);

      // Default is report
      viewModel.selectIndex(-1);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.report),
      );

      viewModel.selectIndex(4);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.report),
      );

      viewModel.selectIndex(99);
      expect(
        container.read(shellViewModelProvider),
        equals(ShellDestination.report),
      );
    });
  });
}
