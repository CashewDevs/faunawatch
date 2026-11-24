import 'package:flutter/foundation.dart';

import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';

/// Which posts the Map tab shows as pins: some categories, then optionally
/// some species within them.
///
/// An empty set means "all". Only the drawn pins follow the filter;
/// FaunaGuard still warns about every post.
@immutable
class MapPinFilter {
  const MapPinFilter({this.categories = const {}, this.species = const {}});

  /// Ticked categories; empty shows every category.
  final Set<ReportCategory> categories;

  /// Ticked species by [CommunityReport.speciesKey]; empty shows every
  /// species. [unknownSpeciesKey] stands for posts the AI did not name.
  final Set<String> species;

  /// The key and label of posts without an AI species guess.
  static const unknownSpeciesKey = '';
  static const unknownSpeciesLabel = 'Unknown species';

  bool get isActive => categories.isNotEmpty || species.isNotEmpty;

  /// How many boxes are ticked, shown on the Filter button.
  int get tickedCount => categories.length + species.length;

  bool matchesCategory(CommunityReport report) =>
      categories.isEmpty || categories.any((c) => c.value == report.category);

  bool matches(CommunityReport report) =>
      matchesCategory(report) &&
      (species.isEmpty || species.contains(report.speciesKey));

  /// The posts this filter shows, in their original order.
  List<CommunityReport> apply(List<CommunityReport> reports) =>
      isActive ? reports.where(matches).toList() : reports;

  /// This filter without the ticked species that no longer appear among
  /// [reports] in the ticked categories, e.g. after a refresh removed their
  /// last post or their category was unticked. A tick nobody can see would
  /// hide pins for no visible reason.
  MapPinFilter prunedFor(Iterable<CommunityReport> reports) {
    if (species.isEmpty) return this;
    final present = {
      for (final report in reports)
        if (matchesCategory(report)) report.speciesKey,
    };
    final kept = species.where(present.contains).toSet();
    return kept.length == species.length
        ? this
        : MapPinFilter(categories: categories, species: kept);
  }

  /// How many of [reports] are in each category; categories without posts
  /// are left out.
  static Map<ReportCategory, int> categoryCounts(
    Iterable<CommunityReport> reports,
  ) {
    final counts = <ReportCategory, int>{};
    for (final report in reports) {
      final category = ReportCategory.values
          .where((c) => c.value == report.category)
          .firstOrNull;
      if (category != null) counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  /// The species found among [reports] in the ticked [categories] (all when
  /// empty), most posts first, then by name, with "Unknown species" last.
  ///
  /// Names are grouped ignoring capitals and extra spaces; each shows the
  /// spelling most of its posts use (the first one seen on a tie).
  static List<MapSpeciesOption> speciesOptions(
    Iterable<CommunityReport> reports, {
    Set<ReportCategory> categories = const {},
  }) {
    final byCategory = MapPinFilter(categories: categories);
    final counts = <String, int>{};
    final spellings = <String, Map<String, int>>{};
    for (final report in reports) {
      if (!byCategory.matchesCategory(report)) continue;
      final key = report.speciesKey;
      counts[key] = (counts[key] ?? 0) + 1;
      final name = report.species;
      if (name != null) {
        final names = spellings[key] ??= {};
        names[name] = (names[name] ?? 0) + 1;
      }
    }
    final options = [
      for (final MapEntry(:key, :value) in counts.entries)
        MapSpeciesOption(
          key: key,
          label: key == unknownSpeciesKey
              ? unknownSpeciesLabel
              : _mostUsed(spellings[key]!),
          count: value,
        ),
    ];
    return options..sort((a, b) {
      if (a.isUnknown != b.isUnknown) return a.isUnknown ? 1 : -1;
      if (a.count != b.count) return b.count.compareTo(a.count);
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  }

  static String _mostUsed(Map<String, int> names) {
    var best = names.entries.first;
    for (final entry in names.entries) {
      if (entry.value > best.value) best = entry;
    }
    return best.key;
  }

  @override
  bool operator ==(Object other) =>
      other is MapPinFilter &&
      setEquals(other.categories, categories) &&
      setEquals(other.species, species);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(species),
  );
}

/// One species in the filter's list.
@immutable
class MapSpeciesOption {
  const MapSpeciesOption({
    required this.key,
    required this.label,
    required this.count,
  });

  /// What the filter stores ([CommunityReport.speciesKey]).
  final String key;
  final String label;

  /// How many posts have this species.
  final int count;

  bool get isUnknown => key == MapPinFilter.unknownSpeciesKey;

  @override
  bool operator ==(Object other) =>
      other is MapSpeciesOption &&
      other.key == key &&
      other.label == label &&
      other.count == count;

  @override
  int get hashCode => Object.hash(key, label, count);

  @override
  String toString() => 'MapSpeciesOption($label, $count)';
}
