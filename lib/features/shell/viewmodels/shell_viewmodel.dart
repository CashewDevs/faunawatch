import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported destinations in the application bottom navigation bar.
enum ShellDestination { feed, gallery, map, chats, notifs, profile }

/// Riverpod Notifier managing the active [ShellDestination] for the application shell.
class ShellViewModel extends Notifier<ShellDestination> {
  @override
  ShellDestination build() {
    return ShellDestination.feed;
  }

  /// Sets the active destination directly.
  void selectDestination(ShellDestination destination) {
    state = destination;
  }

  /// Sets the active destination by index based on [ShellDestination.values].
  void selectIndex(int index) {
    if (index >= 0 && index < ShellDestination.values.length) {
      state = ShellDestination.values[index];
    }
  }
}

/// Provider exposing the [ShellViewModel] and current [ShellDestination].
final shellViewModelProvider =
    NotifierProvider<ShellViewModel, ShellDestination>(ShellViewModel.new);
