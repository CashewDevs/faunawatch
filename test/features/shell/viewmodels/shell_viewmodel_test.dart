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

    test('destinations match the navigation bar order, with Map and without '
        'a notifications tab', () {
      expect(ShellDestination.values, [
        ShellDestination.feed,
        ShellDestination.map,
        ShellDestination.addPost,
        ShellDestination.chats,
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

    group('Back', () {
      ShellViewModel vm() => container.read(shellViewModelProvider.notifier);
      ShellDestination here() => container.read(shellViewModelProvider);

      test('returns through the tabs in reverse order', () {
        vm().selectDestination(ShellDestination.map);
        vm().selectDestination(ShellDestination.profile);
        vm().selectDestination(ShellDestination.chats);

        expect(vm().back(), ShellBackResult.moved);
        expect(here(), ShellDestination.profile);
        expect(vm().back(), ShellBackResult.moved);
        expect(here(), ShellDestination.map);
        expect(vm().back(), ShellBackResult.moved);
        expect(here(), ShellViewModel.home);
      });

      test('at home asks first and exits only on a second Back in time', () {
        final start = DateTime(2026, 11, 22, 10);
        expect(vm().back(now: start), ShellBackResult.confirmExit);
        // Too late: asks again.
        expect(
          vm().back(now: start.add(const Duration(seconds: 3))),
          ShellBackResult.confirmExit,
        );
        expect(
          vm().back(now: start.add(const Duration(seconds: 4))),
          ShellBackResult.exit,
        );
      });

      test('resetToHome goes home and forgets earlier places', () {
        vm().goTo(ShellDestination.map);
        vm().resetToHome();
        expect(here(), ShellViewModel.home);
        vm().goTo(ShellDestination.chats);
        vm().resetToHome();
        expect(vm().back(), ShellBackResult.confirmExit);
      });

      test('goTo is a single Back step', () {
        vm().selectDestination(ShellDestination.profile);
        vm().goTo(ShellDestination.map);
        expect(here(), ShellDestination.map);
        expect(vm().back(), ShellBackResult.moved);
        expect(here(), ShellDestination.profile);
      });

      test('reselecting the current tab adds no step', () {
        vm().selectDestination(ShellDestination.chats);
        vm().selectDestination(ShellDestination.chats);
        expect(vm().back(), ShellBackResult.moved);
        expect(here(), ShellViewModel.home);
        expect(vm().back(), ShellBackResult.confirmExit);
      });

      test('history keeps only the last 20 places', () {
        const tabs = [ShellDestination.map, ShellDestination.chats];
        for (var i = 0; i < 30; i++) {
          vm().selectDestination(tabs[i % 2]);
        }
        var steps = 0;
        while (vm().back() == ShellBackResult.moved) {
          steps++;
        }
        // 20 remembered places, then home.
        expect(steps, 21);
      });
    });
  });
}
