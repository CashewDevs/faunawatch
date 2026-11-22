import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/models/map_pin_spot.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityReport _at(String id, double lat, double lng, {DateTime? createdAt}) =>
    CommunityReport(
      id: id,
      category: 'animal_in_need',
      latitude: lat,
      longitude: lng,
      description: id,
      createdAt: createdAt,
    );

void main() {
  test('reports on the same rounded point share one spot, newest first', () {
    final spots = groupReportsBySpot([
      _at('a-old', 10.12, 123.12, createdAt: DateTime.utc(2026, 11, 1)),
      _at('b', 10.13, 123.12),
      _at('a-new', 10.12, 123.12, createdAt: DateTime.utc(2026, 11, 20)),
      _at('a-undated', 10.12, 123.12),
    ]);
    expect(spots.map((s) => s.reports.map((r) => r.id).toList()), [
      ['a-new', 'a-old', 'a-undated'],
      ['b'],
    ]);
    expect(spots.first.top.id, 'a-new');
    expect(spots.first.count, 3);
    expect(spots.last.count, 1);
  });

  test('undated reports keep a stable order by id', () {
    final spots = groupReportsBySpot([_at('z', 1, 1), _at('m', 1, 1)]);
    expect(spots.single.reports.map((r) => r.id), ['m', 'z']);
  });

  test('the badge shows the count up to nine, then 9+', () {
    MapPinSpot spotOf(int count) =>
        MapPinSpot([for (var i = 0; i < count; i++) _at('r$i', 1, 1)]);
    expect(spotOf(2).countLabel, '2');
    expect(spotOf(9).countLabel, '9');
    expect(spotOf(10).countLabel, '9+');
  });

  test('reads the submission time and rounded point from the RPC row', () {
    final report = CommunityReport.fromJson({
      'id': 'r1',
      'category': 'animal_in_need',
      'latitude': 10.1,
      'longitude': -0.5,
      'description': null,
      'created_at': '2026-11-20T08:30:00+00:00',
    });
    expect(report.createdAt, DateTime.utc(2026, 11, 20, 8, 30));
    expect(report.spotKey, '10.100,-0.500');
    // About 100 m apart: separate pins.
    expect(_at('a', 10.1234, 1).spotKey, isNot(_at('b', 10.1244, 1).spotKey));
    expect(
      CommunityReport.fromJson({
        'id': 'r2',
        'category': 'animal_in_need',
        'latitude': 1,
        'longitude': 2,
      }).createdAt,
      isNull,
    );
  });
}
