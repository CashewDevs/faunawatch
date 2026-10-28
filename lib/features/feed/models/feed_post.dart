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
    this.imageAssets = const [],
  });
  final String id, title, author, location, summary, body;

  /// Local placeholder photos; remote report media is not connected yet.
  final List<String> imageAssets;
}

const sampleMapPost = FeedPost(
  id: 'sample-cebu-incident',
  imageAssets: [
    AppAssets.avatarGarfield,
    AppAssets.avatarPanda,
    AppAssets.avatarTweety,
  ],
  title: 'Wildlife spotted near a walking trail',
  author: 'Sample spotter',
  location: 'Cebu City ? Approximate location',
  summary: 'A small wild bird was spotted resting beside a walking trail.',
  body:
      'The bird stayed near the trees before flying back into the canopy. '
      'This fictional post demonstrates how a wildlife report opens from the map. '
      'It is not a real sighting, verified species identification, or active alert.',
);
