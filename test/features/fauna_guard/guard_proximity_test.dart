import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_proximity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'guard_fakes.dart';

void main() {
  test('uses spherical distance, including across the date line', () {
    expect(guardFix(0).distanceTo(0, 0), 0);
    expect(guardFix(1000).distanceTo(0, 0), closeTo(1000, 0.01));
    final fix = GuardLocation(
      latitude: 0,
      longitude: 179.999,
      accuracy: 5,
      timestamp: DateTime.now(),
    );
    expect(fix.distanceTo(0, -179.999), closeTo(222.39, 0.1));
  });

  test(
    'outside, 1 km, 500 m, then boundary jitter produces only two alerts',
    () {
      final tracker = GuardProximityTracker();
      expect(tracker.evaluate(guardFix(1001), [guardReport]), isEmpty);
      expect(
        tracker.evaluate(guardFix(999), [guardReport]).single.proximity,
        GuardProximity.gettingCloser,
      );
      expect(tracker.evaluate(guardFix(1001), [guardReport]), isEmpty);
      expect(tracker.evaluate(guardFix(999), [guardReport]), isEmpty);
      expect(
        tracker.evaluate(guardFix(499), [guardReport]).single.proximity,
        GuardProximity.nearby,
      );
      expect(tracker.evaluate(guardFix(501), [guardReport]), isEmpty);
      expect(tracker.evaluate(guardFix(499), [guardReport]), isEmpty);
    },
  );

  test(
    'starting inside 500 m emits only Nearby and watches every category',
    () {
      final tracker = GuardProximityTracker();
      final reports = [
        for (final category in [
          'animal_in_need',
          'potentially_dangerous_animal',
          'possible_invasive_species',
          'other_wildlife_incident',
        ])
          CommunityReport(
            id: category,
            category: category,
            latitude: 0,
            longitude: 0,
            description: '',
          ),
      ];
      final alerts = tracker.evaluate(guardFix(100), reports);
      expect(alerts, hasLength(4));
      expect(
        alerts.every((alert) => alert.proximity == GuardProximity.nearby),
        isTrue,
      );
    },
  );

  test('invalid device/report coordinates do not trigger an alert', () {
    final tracker = GuardProximityTracker();
    final invalidFix = GuardLocation(
      latitude: double.nan,
      longitude: 0,
      accuracy: 5,
      timestamp: DateTime.now(),
    );
    expect(tracker.evaluate(invalidFix, [guardReport]), isEmpty);
    expect(
      tracker.evaluate(guardFix(0), [
        const CommunityReport(
          id: 'bad',
          category: '',
          latitude: 91,
          longitude: 0,
          description: '',
        ),
      ]),
      isEmpty,
    );
  });
}
