import 'package:faunawatch/core/constants/app_assets.dart';

/// Local sample shared by the map and feed until reports are connected.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.title,
    required this.author,
    required this.location,
    required this.summary,
    required this.body,
    this.authorAvatarAsset,
    this.imageAssets = const [],
    this.likeCount = 0,
  });
  final String id, title, author, location, summary, body;
  final String? authorAvatarAsset;

  /// Local placeholder photos; remote report media is not connected yet.
  final List<String> imageAssets;
  final int likeCount;
}

/// Shortens large counts for tight layouts, e.g. 1406 becomes 1.4K.
String formatCompactCount(int count) {
  if (count < 1000) return '$count';
  final thousands = (count / 100).floor() / 10;
  final label = thousands == thousands.truncateToDouble()
      ? thousands.toStringAsFixed(0)
      : thousands.toStringAsFixed(1);
  return '${label}K';
}

const sampleMapPost = FeedPost(
  id: 'sample-cebu-incident',
  authorAvatarAsset: AppAssets.avatarPanda,
  imageAssets: [
    AppAssets.avatarGarfield,
    AppAssets.avatarPanda,
    AppAssets.avatarTweety,
  ],
  likeCount: 128,
  title: 'Wildlife spotted near a walking trail',
  author: 'Sample spotter',
  location: 'Cebu City · Approximate location',
  summary: 'A small wild bird was spotted resting beside a walking trail.',
  body:
      'The bird stayed near the trees before flying back into the canopy. '
      'This fictional post demonstrates how a wildlife report opens from the map. '
      'It is not a real sighting, verified species identification, or active alert.',
);
