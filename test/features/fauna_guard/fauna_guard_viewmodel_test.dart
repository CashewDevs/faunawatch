import 'dart:async';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';
import 'package:faunawatch/features/fauna_guard/models/fauna_guard_state.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_location_service.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_notification_service.dart';
import 'package:faunawatch/features/fauna_guard/viewmodels/fauna_guard_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'guard_fakes.dart';

void main() {
  late ProviderContainer container;
  late FakeGuardLocation location;
  late FakeGuardNotifications notifications;
  late FakeGuardReports reports;
  late FaunaGuardViewModel vm;
  late StreamController<String?> users;
  FaunaGuardState state() => container.read(faunaGuardViewModelProvider);

  setUp(() async {
    location = FakeGuardLocation();
    notifications = FakeGuardNotifications();
    reports = FakeGuardReports();
    users = StreamController<String?>();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => users.stream),
        guardLocationServiceProvider.overrideWithValue(location),
        guardNotificationServiceProvider.overrideWithValue(notifications),
        communityReportsServiceProvider.overrideWithValue(reports),
      ],
    );
    vm = container.read(faunaGuardViewModelProvider.notifier);
    users.add('user-a');
    await pumpEventQueue();
  });
  tearDown(() async {
    container.dispose();
    await location.fixes.close();
    await users.close();
  });

  test(
    'starts off with no GPS access and enables only on explicit action',
    () async {
      expect(state().status, GuardStatus.off);
      expect(location.requests, 0);
      await vm.enable();
      expect(state().status, GuardStatus.starting);
      location.fixes.add(guardFix(1200));
      await pumpEventQueue();
      expect(state().status, GuardStatus.active);
      expect(state().location, isNotNull);
      expect(notifications.shown, isEmpty);
    },
  );

  test(
    'moving emits one notification per band; disabling releases GPS and location',
    () async {
      await vm.enable();
      for (final meters in [900.0, 850.0, 400.0, 450.0]) {
        location.fixes.add(guardFix(meters));
        await pumpEventQueue();
      }
      expect(notifications.shown, hasLength(2));
      expect(notifications.shown.first.title, contains('getting closer'));
      expect(notifications.shown.last.body, contains('500 m'));
      expect(notifications.shown.last.body, contains('approximate'));
      vm.disable();
      await pumpEventQueue();
      expect(location.fixes.hasListener, isFalse);
      expect(state().location, isNull);
      expect(state().alert, isNull);
      expect(notifications.clears, greaterThan(0));
    },
  );

  test(
    'permission/notification failures leave tracking off with actionable text',
    () async {
      location.failure = const GuardException(
        GuardFailure.permissionPermanentlyDenied,
      );
      await vm.enable();
      expect(state().status, GuardStatus.off);
      expect(state().message, contains('app settings'));
      expect(location.watches, 0);
      location.failure = null;
      notifications.failure = const GuardException(
        GuardFailure.notificationsDenied,
      );
      await vm.enable();
      expect(state().message, contains('notifications'));
      expect(location.watches, 0);
      await vm.openSettings();
      expect(location.settings, 1);
    },
  );

  test(
    'turning off during permission request cannot start tracking later',
    () async {
      location.permission = Completer<void>();
      final enabling = vm.enable();
      await pumpEventQueue();
      vm.disable();
      location.permission!.complete();
      await enabling;
      expect(location.watches, 0);
      expect(state().status, GuardStatus.off);
    },
  );

  test(
    'sign-out and account replacement cancel tracking without automatic opt-in',
    () async {
      await vm.enable();
      location.fixes.add(guardFix(900));
      await pumpEventQueue();
      users.add('user-b');
      await pumpEventQueue();
      expect(state().status, GuardStatus.off);
      expect(state().location, isNull);
      expect(location.fixes.hasListener, isFalse);
      users.add(null);
      await pumpEventQueue();
      await vm.enable();
      expect(state().message, contains('Sign in'));
    },
  );

  test(
    'revoked reports are removed and a failed refresh stops stale alerts',
    () async {
      await vm.enable();
      location.fixes.add(guardFix(400));
      await pumpEventQueue();
      reports.reports = [];
      await vm.refreshReports();
      expect(state().alert, isNull);
      reports.fail = true;
      await vm.refreshReports();
      expect(state().status, GuardStatus.off);
      expect(state().message, contains('refresh'));
      expect(location.fixes.hasListener, isFalse);
    },
  );

  test(
    'rejects historical fixes; stream errors stop with a retry message',
    () async {
      await vm.enable();
      location.fixes.add(
        guardFix(
          200,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      await pumpEventQueue();
      expect(state().location, isNull);
      expect(notifications.shown, isEmpty);
      location.fixes.addError(StateError('unavailable'));
      await pumpEventQueue();
      expect(state().status, GuardStatus.off);
      expect(state().message, contains('Location updates stopped'));
    },
  );

  testWidgets(
    'no first fix times out and periodic refresh runs while enabled',
    (tester) async {
      await vm.enable();
      await tester.pump(const Duration(seconds: 31));
      expect(state().status, GuardStatus.off);
      expect(state().message, contains('Could not get your location'));
      await vm.enable();
      location.fixes.add(guardFix(1500));
      await tester.pump();
      final previous = reports.loads;
      await tester.pump(const Duration(minutes: 1));
      expect(reports.loads, previous + 1);
      vm.disable();
      await tester.pump(const Duration(minutes: 1));
      expect(reports.loads, previous + 1);
    },
  );

  test('disposal during a pending start prevents late work', () async {
    reports.pending = Completer();
    final enabling = vm.enable();
    await pumpEventQueue();
    container.dispose();
    reports.pending!.complete([guardReport]);
    await enabling;
    expect(location.watches, 0);
  });

  test(
    'a canceled report load cannot replace reports in a newer session',
    () async {
      final pending = Completer<List<CommunityReport>>();
      reports.pending = pending;
      final oldStart = vm.enable();
      await pumpEventQueue();
      vm.disable();
      reports.pending = null;
      await vm.enable();
      pending.complete([]);
      await oldStart;
      location.fixes.add(guardFix(400));
      await pumpEventQueue();
      expect(notifications.shown.single.title, contains('nearby'));
    },
  );

  testWidgets(
    'cannot start location service after the app is backgrounded during loading',
    (tester) async {
      reports.pending = Completer();
      final starting = vm.enable();
      await tester.pump();
      vm.setForeground(false);
      reports.pending!.complete([guardReport]);
      await starting;
      expect(location.watches, 0);
      expect(state().message, contains('Keep FaunaWatch open'));
    },
  );
}
