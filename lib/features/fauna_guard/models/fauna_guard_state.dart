import 'guard_location.dart';
import 'guard_proximity.dart';

enum GuardStatus { off, starting, active }

enum GuardFailure {
  unsupported,
  locationDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  notificationsDenied,
  locationUnavailable,
}

class GuardException implements Exception {
  const GuardException(this.failure);
  final GuardFailure failure;
}

class FaunaGuardState {
  const FaunaGuardState({
    this.status = GuardStatus.off,
    this.location,
    this.alert,
    this.additionalReports = 0,
    this.message,
  });

  final GuardStatus status;
  final GuardLocation? location;
  final GuardAlert? alert;
  final int additionalReports;
  final String? message;

  bool get isEnabled => status != GuardStatus.off;

  String? get alertTitle => alert == null
      ? null
      : alert!.proximity == GuardProximity.nearby
      ? 'FaunaGuard: wildlife report nearby'
      : 'FaunaGuard: getting closer';

  String? get alertBody {
    final current = alert;
    if (current == null) return null;
    final radius = current.proximity == GuardProximity.nearby
        ? '500 m'
        : '1 km';
    final others = additionalReports == 0
        ? ''
        : ' $additionalReports other ${additionalReports == 1 ? 'report is' : 'reports are'} also nearby.';
    return '${current.report.preview.title} reported within $radius of your location.$others '
        'Report locations are approximate; wildlife may have moved. Keep a safe distance.';
  }

  FaunaGuardState copyWith({
    GuardStatus? status,
    GuardLocation? location,
    GuardAlert? alert,
    int? additionalReports,
    String? message,
    bool clearAlert = false,
    bool clearMessage = false,
  }) => FaunaGuardState(
    status: status ?? this.status,
    location: location ?? this.location,
    alert: clearAlert ? null : alert ?? this.alert,
    additionalReports: additionalReports ?? this.additionalReports,
    message: clearMessage ? null : message ?? this.message,
  );
}
