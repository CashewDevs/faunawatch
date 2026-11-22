/// What the map's preview dialog shows for a tapped pin.
///
/// Real pins come from `community_reports()`, which has no author and only
/// approximate locations. [author] is the placeholder shown until the dialog
/// has loaded the matching feed post, which brings the photo and the poster's
/// name and picture.
class MapPostPreview {
  const MapPostPreview({
    required this.id,
    required this.title,
    required this.author,
    required this.location,
    required this.body,
  });

  final String id, title, author, location, body;
}
