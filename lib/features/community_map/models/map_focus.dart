import 'package:faunawatch/features/feed/models/feed_post.dart';

/// A post's spot to show on the community map.
///
/// For other people's posts the point is rounded to about 100 m (see
/// [FeedPost.approxLatitude]), where their public pin is. For the owner's own
/// post it is the exact point ([isExact]), read through owner access. The
/// owner's exact point, and any post that is not public (pending or declined),
/// get a temporary marker that only the owner sees, since it is drawn on their
/// own device and never stored.
class MapFocus {
  const MapFocus({
    required this.postId,
    required this.latitude,
    required this.longitude,
    required this.isPublic,
    this.isExact = false,
  });

  final String postId;
  final double latitude, longitude;

  /// Approved: the post has a public pin (at its rounded point).
  final bool isPublic;

  /// The owner's exact point rather than the rounded one.
  final bool isExact;

  /// Whether the owner-only marker is drawn.
  bool get showsOwnerMarker => isExact || !isPublic;

  /// Label of the owner-only marker.
  static const privateLabel = 'Only you can see this';

  /// The rounded point of [post]; null when the post has no location.
  static MapFocus? fromPost(FeedPost post, {required bool isPublic}) {
    final latitude = post.approxLatitude, longitude = post.approxLongitude;
    if (latitude == null || longitude == null) return null;
    return MapFocus(
      postId: post.id,
      latitude: latitude,
      longitude: longitude,
      isPublic: isPublic,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MapFocus &&
      other.postId == postId &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.isPublic == isPublic &&
      other.isExact == isExact;

  @override
  int get hashCode =>
      Object.hash(postId, latitude, longitude, isPublic, isExact);
}
