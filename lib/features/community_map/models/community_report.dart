import 'package:faunawatch/features/community_map/models/map_post_preview.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';

/// Public report data returned by community_reports; never contains exact GPS.
class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.photoPath,
    this.createdAt,
    this.species,
  });
  final String id, category, description;
  final double latitude, longitude;

  /// The first photo's path in the private `report-images` bucket, used for
  /// the pin's picture; null without a photo or before the photo migration.
  final String? photoPath;

  /// When the report was submitted; decides which post's photo a shared pin
  /// shows (the newest).
  final DateTime? createdAt;

  /// The AI's top species guess (its common name), as the Feed shows it;
  /// null when the AI named none. The species a poster typed in is not part
  /// of `community_reports`, so it is not used here.
  final String? species;

  /// [species] ignoring capitals and extra spaces, so "Cane toad" and
  /// "cane  Toad" are one species in the map's filter; empty without a guess.
  String get speciesKey =>
      species?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';

  /// The rounded point (3 decimals, about 100 m) this report's pin sits on.
  /// Reports with the same key share one pin.
  String get spotKey =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  factory CommunityReport.fromJson(Map<String, dynamic> row) => CommunityReport(
    id: row['id'] as String,
    category: row['category'] as String,
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    description: row['description'] as String? ?? 'No description provided.',
    photoPath: switch (row['photo_path']) {
      final String path when path.trim().isNotEmpty => path,
      _ => null,
    },
    createdAt: switch (row['created_at']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    },
    species: _topSpecies(row['possible_species']),
  );

  /// The first guess's common name, like `FeedPost`'s AI guess.
  static String? _topSpecies(Object? value) {
    if (value is! List || value.isEmpty) return null;
    final first = value.first;
    if (first is! Map) return null;
    for (final name in [first['common_name'], first['name']]) {
      if (name is String && name.trim().isNotEmpty) return name.trim();
    }
    return null;
  }

  MapPostPreview get preview => MapPostPreview(
    id: id,
    title:
        ReportCategory.values
            .where((c) => c.value == category)
            .firstOrNull
            ?.label ??
        'Wildlife report',
    author: 'Community spotter',
    location:
        '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)} · Approximate location',

    body: description,
  );
}
