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
  });
  final String id, category, description;
  final double latitude, longitude;

  /// The first photo's path in the private `report-images` bucket, used for
  /// the pin's picture; null without a photo or before the photo migration.
  final String? photoPath;

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
  );

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
        '${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)} · Approximate location',

    body: description,
  );
}
