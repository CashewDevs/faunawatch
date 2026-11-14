/// What the map's preview dialog shows for a tapped pin.
///
/// Real pins come from `community_reports()` and stay anonymous and
/// approximate; the dialog loads its photo separately. The matching feed post
/// has the author and place name.
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
