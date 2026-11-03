import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';

/// Public report data returned by community_reports; never contains exact GPS.
class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.description,
  });
  final String id, category, description;
  final double latitude, longitude;

  factory CommunityReport.fromJson(Map<String, dynamic> row) => CommunityReport(
    id: row['id'] as String,
    category: row['category'] as String,
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    description: row['description'] as String? ?? 'No description provided.',
  );

  FeedPost get post => FeedPost(
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
    summary: description,
    body: description,
  );
}
