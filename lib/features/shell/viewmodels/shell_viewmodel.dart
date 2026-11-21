import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';

/// Supported destinations in the application bottom navigation bar.
enum ShellDestination { feed, chats, addPost, notifs, profile }

/// A place in the shell: the bottom tab and, inside Feed, Map or For You.
typedef ShellPlace = ({ShellDestination destination, FeedTab feedTab});

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
/// Every tab change (bottom tabs and Feed's Map / For You) is remembered, so
/// Back returns to the previous place. With nothing left to go back to, Back
/// first returns home (Feed › For You); at home it asks for a second Back
/// within [exitWindow] before the app closes.
class ShellViewModel extends Notifier<ShellDestination> {
  static const home = (
    destination: ShellDestination.feed,
    feedTab: FeedTab.forYou,
  );
  static const exitWindow = Duration(seconds: 2);
  static const _maxHistory = 20;

  final _history = <ShellPlace>[];
  bool _moving = false;
  DateTime? _exitAskedAt;

  @override
  ShellDestination build() {
    _history.clear();
    _exitAskedAt = null;
    // Switching between Map and For You inside Feed is a step too.
    ref.listen(feedTabViewModelProvider, (previous, next) {
      if (_moving || previous == null || previous == next) return;
      _remember((destination: state, feedTab: previous));
    });
    return ShellDestination.feed;
  }

  ShellPlace get _here =>
      (destination: state, feedTab: ref.read(feedTabViewModelProvider));

  /// Sets the active destination directly.
  void selectDestination(ShellDestination destination) => goTo(destination);

  /// Sets the active destination by index based on [ShellDestination.values].
  void selectIndex(int index) {
    if (index >= 0 && index < ShellDestination.values.length) {
      goTo(ShellDestination.values[index]);
    }
  }

  /// Opens [destination] (and [feedTab], when given) as one step that Back
  /// undoes.
  void goTo(ShellDestination destination, {FeedTab? feedTab}) {
    final here = _here;
    _move(destination, feedTab);
    if (_here != here) _remember(here);
  }

  /// Goes home and forgets every earlier place, e.g. after signing out.
  void resetToHome() {
    _history.clear();
    _exitAskedAt = null;
    _move(home.destination, home.feedTab);
  }

  /// Handles the system Back button. [now] is for tests.
  ShellBackResult back({DateTime? now}) {
    while (_history.isNotEmpty) {
      final place = _history.removeLast();
      if (place == _here) continue;
      _move(place.destination, place.feedTab);
      return ShellBackResult.moved;
    }
    if (_here != home) {
      _move(home.destination, home.feedTab);
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

  void _move(ShellDestination destination, FeedTab? feedTab) {
    _moving = true;
    try {
      if (feedTab != null) {
        ref.read(feedTabViewModelProvider.notifier).select(feedTab);
      }
      state = destination;
    } finally {
      _moving = false;
    }
  }

  void _remember(ShellPlace place) {
    if (_history.isNotEmpty && _history.last == place) return;
    _history.add(place);
    if (_history.length > _maxHistory) _history.removeAt(0);
  }
}

/// Provider exposing the [ShellViewModel] and current [ShellDestination].
final shellViewModelProvider =
    NotifierProvider<ShellViewModel, ShellDestination>(ShellViewModel.new);
