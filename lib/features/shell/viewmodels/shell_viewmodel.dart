import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO(navigation): Unresolved Navigation Structure Mapping (SDD §6.1 vs §6.3)
// SDD Section 6.1 specifies four bottom-navigation destinations: Report, Map, Alerts, and Profile.
// SDD Section 6.3 describes six functional screens (Dashboard/Feed, Map, FaunaLens, Gallery, Messages, Profile)
// along with a Header Bar returning to Dashboard and a top Navigation Dots Bar.
// This discrepancy represents an unresolved architectural and UI decision.
// CRITICAL: Future AI agents and contributors MUST NOT modify this navigation structure,
// add or remove destinations, or change the shell navigation hierarchy without explicit
// team discussion and approval.
enum ShellDestination {
  report,
  map,
  alerts,
  profile,
}

/// Riverpod Notifier managing the active [ShellDestination] for the application shell.
class ShellViewModel extends Notifier<ShellDestination> {
  @override
  ShellDestination build() {
    return ShellDestination.report;
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
    NotifierProvider<ShellViewModel, ShellDestination>(
  ShellViewModel.new,
);
