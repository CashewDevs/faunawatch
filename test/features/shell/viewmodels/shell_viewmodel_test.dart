import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
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

    group('Back', () {
      ShellViewModel vm() => container.read(shellViewModelProvider.notifier);
      ShellPlace here() => (
        destination: container.read(shellViewModelProvider),
        feedTab: container.read(feedTabViewModelProvider),
      );
      FeedTabViewModel tabs() =>
          container.read(feedTabViewModelProvider.notifier);

      test('returns through tabs and feed sub-tabs in reverse order', () {
        tabs().select(FeedTab.map);
        vm().selectDestination(ShellDestination.profile);
        vm().selectDestination(ShellDestination.chats);

        expect(vm().back(), ShellBackResult.moved);
        expect(here().destination, ShellDestination.profile);
        expect(vm().back(), ShellBackResult.moved);
        expect(here(), (
          destination: ShellDestination.feed,
          feedTab: FeedTab.map,
        ));
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
        tabs().select(FeedTab.map);
        vm().resetToHome();
        expect(here(), ShellViewModel.home);
        vm().goTo(ShellDestination.notifs);
        vm().resetToHome();
        expect(vm().back(), ShellBackResult.confirmExit);
      });

      test('goTo with a feed tab is a single Back step', () {
        vm().selectDestination(ShellDestination.profile);
        vm().goTo(ShellDestination.feed, feedTab: FeedTab.map);
        expect(here(), (
          destination: ShellDestination.feed,
          feedTab: FeedTab.map,
        ));
        expect(vm().back(), ShellBackResult.moved);
        // The feed tab is restored too, as it was before the jump.
        expect(here(), (
          destination: ShellDestination.profile,
          feedTab: FeedTab.forYou,
        ));
      });

      test('reselecting the current tab adds no step', () {
        vm().selectDestination(ShellDestination.chats);
        vm().selectDestination(ShellDestination.chats);
        expect(vm().back(), ShellBackResult.moved);
        expect(here(), ShellViewModel.home);
        expect(vm().back(), ShellBackResult.confirmExit);
      });
    });
  });
}
