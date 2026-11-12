import 'package:faunawatch/core/constants/app_assets.dart';

/// What the map's preview dialog shows for a tapped pin.
///
/// Real pins come from `community_reports()` and stay anonymous and
/// approximate; the matching feed post has the author and place name. The
/// warning demo's "Sample incident" pin is not a report at all, so it has a
/// preview of its own and no feed post.
class MapPostPreview {
  const MapPostPreview({
    required this.id,
    required this.title,
    required this.author,
    required this.location,
    required this.body,
    this.imageAssets = const [],
    this.isDemo = false,
  });

  final String id, title, author, location, body;

  /// Local placeholder photos, used only by the demo.
  final List<String> imageAssets;
  final bool isDemo;

  static const demoId = 'sample-cebu-incident';

  static const demo = MapPostPreview(
    id: demoId,
    title: 'Wildlife spotted near a walking trail',
    author: 'Sample spotter',
    location: 'Cebu City · Approximate location',
    body: 'Demo only - Not a real wildlife report',
    imageAssets: [
      AppAssets.avatarGarfield,
      AppAssets.avatarPanda,
      AppAssets.avatarTweety,
    ],
    isDemo: true,
  );
}
