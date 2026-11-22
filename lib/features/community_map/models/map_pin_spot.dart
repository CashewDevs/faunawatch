import 'community_report.dart';

/// The approved reports that share one rounded map point, and so one pin.
///
/// Rounding to about 1 km puts nearby posts on exactly the same point, where
/// their pins would hide each other. The map draws one pin per spot, showing
/// the newest post's photo, with a number badge when it holds more than one.
class MapPinSpot {
  MapPinSpot(List<CommunityReport> reports)
    : assert(reports.isNotEmpty),
      reports = List.unmodifiable(reports);

  /// Newest first; never empty.
  final List<CommunityReport> reports;

  /// The newest report: its photo is the pin's picture and its id is the
  /// pin's id.
  CommunityReport get top => reports.first;

  int get count => reports.length;

  /// The badge text: the count, or "9+" above nine.
  String get countLabel => count > 9 ? '9+' : '$count';
}

/// Groups [reports] by their rounded point ([CommunityReport.spotKey]).
///
/// Spots keep the order in which they first appear; inside a spot the newest
/// report comes first (unknown dates last, then by id so the order is stable).
List<MapPinSpot> groupReportsBySpot(Iterable<CommunityReport> reports) {
  final bySpot = <String, List<CommunityReport>>{};
  for (final report in reports) {
    (bySpot[report.spotKey] ??= []).add(report);
  }
  return [
    for (final group in bySpot.values) MapPinSpot(group..sort(_newestFirst)),
  ];
}

int _newestFirst(CommunityReport a, CommunityReport b) {
  final aAt = a.createdAt, bAt = b.createdAt;
  if (aAt != null && bAt != null && aAt != bAt) return bAt.compareTo(aAt);
  if ((aAt == null) != (bAt == null)) return aAt == null ? 1 : -1;
  return a.id.compareTo(b.id);
}
