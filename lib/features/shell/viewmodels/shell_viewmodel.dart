import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported destinations in the application bottom navigation bar, in the
/// bar's order: Feed · Map | + | Chats · Profile.
///
/// Notifications are not a tab: the bell in the top bar opens them as a page
/// on top of the shell.
enum ShellDestination { feed, map, addPost, chats, profile }

/// What the system Back button did on the shell.
enum ShellBackResult {
  /// Went back to the previous place.
  moved,

  /// Already home; the user was asked to press Back again to exit.
  confirmExit,

  /// Pressed again in time: the app may close.
  exit,
}

/// Riverpod Notifier managing the active [ShellDestination] for the
/// application shell, and where the system Back button goes.
///
/// Every tab change is remembered, so Back returns to the previous tab. With
/// nothing left to go back to, Back first returns home (Feed); at home it asks
/// for a second Back within [exitWindow] before the app closes.
class ShellViewModel extends Notifier<ShellDestination> {
  static const home = ShellDestination.feed;
  static const exitWindow = Duration(seconds: 2);
  static const _maxHistory = 20;

  final _history = <ShellDestination>[];
  DateTime? _exitAskedAt;

  @override
  ShellDestination build() {
    _history.clear();
    _exitAskedAt = null;
    return home;
  }

  /// Sets the active destination directly.
  void selectDestination(ShellDestination destination) => goTo(destination);

  /// Sets the active destination by index based on [ShellDestination.values].
  void selectIndex(int index) {
    if (index >= 0 && index < ShellDestination.values.length) {
      goTo(ShellDestination.values[index]);
    }
  }

  /// Opens [destination] as one step that Back undoes.
  void goTo(ShellDestination destination) {
    final here = state;
    state = destination;
    if (state != here) _remember(here);
  }

  /// Goes home and forgets every earlier place, e.g. after signing out.
  void resetToHome() {
    _history.clear();
    _exitAskedAt = null;
    state = home;
  }

  /// Handles the system Back button. [now] is for tests.
  ShellBackResult back({DateTime? now}) {
    while (_history.isNotEmpty) {
      final place = _history.removeLast();
      if (place == state) continue;
      state = place;
      return ShellBackResult.moved;
    }
    if (state != home) {
      state = home;
      return ShellBackResult.moved;
    }
    final time = now ?? DateTime.now();
    final asked = _exitAskedAt;
    if (asked != null && time.difference(asked) < exitWindow) {
      _exitAskedAt = null;
      return ShellBackResult.exit;
    }
    _exitAskedAt = time;
    return ShellBackResult.confirmExit;
  }

  void _remember(ShellDestination place) {
    if (_history.isNotEmpty && _history.last == place) return;
    _history.add(place);
    if (_history.length > _maxHistory) _history.removeAt(0);
  }
}

/// Provider exposing the [ShellViewModel] and current [ShellDestination].
final shellViewModelProvider =
    NotifierProvider<ShellViewModel, ShellDestination>(ShellViewModel.new);
