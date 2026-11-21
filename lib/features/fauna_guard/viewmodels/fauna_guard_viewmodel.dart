import 'dart:async';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fauna_guard_state.dart';
import '../models/guard_location.dart';
import '../models/guard_proximity.dart';
import '../services/guard_location_service.dart';
import '../services/guard_notification_service.dart';

/// Owns the opt-in session, including while the map/app is in the background.
/// Nothing persists the user's coordinates or automatically restarts tracking.
class FaunaGuardViewModel extends Notifier<FaunaGuardState> {
  int _generation = 0;
  StreamSubscription<GuardLocation>? _positions;
  Timer? _refreshTimer;
  Timer? _firstFixTimer;
  List<CommunityReport> _reports = const [];
  GuardProximityTracker _tracker = GuardProximityTracker();
  bool _refreshing = false;
  bool _enabled = false;
  bool _inForeground = true;
  late String? _userId;
  late GuardLocationService _locationService;
  late GuardNotificationService _notifications;
  late CommunityReportsService _reportsService;

  @override
  FaunaGuardState build() {
    _userId = ref.watch(
      currentUserIdProvider.select((user) => user.valueOrNull),
    );
    _locationService = ref.watch(guardLocationServiceProvider);
    _notifications = ref.watch(guardNotificationServiceProvider);
    final notifications = _notifications;
    ref.onDispose(() {
      ++_generation;
      _enabled = false;
      _cancelTracking();
      unawaited(notifications.clear().catchError((Object _) {}));
    });
    return const FaunaGuardState();
  }

  bool _current(int generation) => generation == _generation;

  Future<void> enable() async {
    if (state.isEnabled) return;
    if (_userId == null) {
      state = const FaunaGuardState(message: 'Sign in to turn on FaunaGuard.');
      return;
    }
    final generation = ++_generation;
    _enabled = true;
    _tracker = GuardProximityTracker();
    state = const FaunaGuardState(status: GuardStatus.starting);
    try {
      await _locationService.requestAccess();
      if (!_current(generation)) return;
      await _notifications.requestAccess();
      if (!_current(generation)) return;
      _reportsService = ref.read(communityReportsServiceProvider);
      final reports = await _reportsService.load().timeout(
        const Duration(seconds: 20),
      );
      if (!_current(generation)) return;
      _reports = reports;
      if (!_inForeground) {
        _fail(
          generation,
          'Keep FaunaWatch open until FaunaGuard starts, then you can lock your phone.',
        );
        return;
      }
      _positions = _locationService.watch().listen(
        (location) => _onLocation(location, generation),
        onError: (Object _) => _fail(
          generation,
          'Location updates stopped. Check location access and turn FaunaGuard on again.',
        ),
        onDone: () => _fail(
          generation,
          'Location updates stopped. Turn FaunaGuard on again to retry.',
        ),
      );
      _firstFixTimer = Timer(
        const Duration(seconds: 30),
        () => _fail(
          generation,
          'Could not get your location. Check GPS and turn FaunaGuard on again.',
        ),
      );
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => refreshReports(),
      );
    } on GuardException catch (error) {
      _fail(generation, switch (error.failure) {
        GuardFailure.unsupported =>
          'FaunaGuard background alerts are available on Android and iOS.',
        GuardFailure.locationDisabled =>
          'Turn on device Location Services, then try FaunaGuard again.',
        GuardFailure.permissionDenied =>
          'Location access is needed to turn on FaunaGuard.',
        GuardFailure.permissionPermanentlyDenied =>
          'Allow location access in app settings, then try FaunaGuard again.',
        GuardFailure.notificationsDenied =>
          'Allow notifications in app settings, then try FaunaGuard again.',
        GuardFailure.locationUnavailable =>
          'Could not get your location. Try FaunaGuard again.',
      });
    } catch (_) {
      _fail(
        generation,
        'Could not start FaunaGuard. Check your connection and location access, then retry.',
      );
    }
  }

  void _onLocation(GuardLocation location, int generation) {
    if (!_current(generation) || !location.isValid) return;
    // Reject historical/late fixes, which can otherwise trigger an alert after
    // a device wakes up or move the marker backwards.
    final age = DateTime.now().difference(location.timestamp);
    if (age > const Duration(minutes: 2) ||
        age < const Duration(seconds: -10) ||
        (state.location != null &&
            !location.timestamp.isAfter(state.location!.timestamp))) {
      return;
    }
    _firstFixTimer?.cancel();
    state = state.copyWith(status: GuardStatus.active, location: location);
    final alerts = _tracker.evaluate(location, _reports);
    if (alerts.isEmpty) return;
    state = state.copyWith(
      alert: alerts.first,
      additionalReports: alerts.length - 1,
    );
    unawaited(_notify(generation, state.alertTitle!, state.alertBody!));
  }

  Future<void> _notify(int generation, String title, String body) async {
    try {
      if (!_current(generation)) return;
      await _notifications.show(title: title, body: body);
      // A notification may have finished posting after the user turned off.
      if (!_current(generation) && !_enabled) await _notifications.clear();
    } catch (_) {
      _fail(
        generation,
        'Could not show FaunaGuard alerts. Check notification access and turn it on again.',
      );
    }
  }

  Future<void> refreshReports() async {
    if (!state.isEnabled || _refreshing) return;
    final generation = _generation;
    _refreshing = true;
    try {
      final reports = await _reportsService.load().timeout(
        const Duration(seconds: 20),
      );
      if (!_current(generation)) return;
      _reports = reports;
      if (state.alert != null &&
          !reports.any((r) => r.id == state.alert!.report.id)) {
        state = state.copyWith(clearAlert: true);
        await _notifications.clear();
        if (!_current(generation)) return;
      }
      final location = state.location;
      if (location != null) {
        // New approvals can alert even if the user has not moved again.
        final alerts = _tracker.evaluate(location, reports);
        if (alerts.isNotEmpty) {
          state = state.copyWith(
            alert: alerts.first,
            additionalReports: alerts.length - 1,
          );
          await _notify(generation, state.alertTitle!, state.alertBody!);
        }
      }
    } catch (_) {
      _fail(
        generation,
        'Could not refresh approved reports. FaunaGuard stopped. Connect and turn it on again.',
      );
    } finally {
      if (_current(generation)) _refreshing = false;
    }
  }

  void _cancelTracking() {
    unawaited(_positions?.cancel());
    _positions = null;
    _refreshTimer?.cancel();
    _firstFixTimer?.cancel();
    _reports = const [];
    _refreshing = false;
  }

  void _fail(int generation, String message) {
    if (!_current(generation)) return;
    disable();
    state = FaunaGuardState(message: message);
  }

  void disable() {
    ++_generation;
    _enabled = false;
    _cancelTracking();
    state = const FaunaGuardState();
    unawaited(_notifications.clear().catchError((Object _) {}));
  }

  void dismissAlert() => state = state.copyWith(clearAlert: true);
  void setForeground(bool value) => _inForeground = value;
  void dismissMessage() => state = state.copyWith(clearMessage: true);

  Future<void> openSettings() async {
    try {
      await _locationService.openSettings();
    } catch (_) {
      state = state.copyWith(
        message: 'Open your device settings to review FaunaWatch permissions.',
      );
    }
  }
}

final faunaGuardViewModelProvider =
    NotifierProvider<FaunaGuardViewModel, FaunaGuardState>(
      FaunaGuardViewModel.new,
    );
