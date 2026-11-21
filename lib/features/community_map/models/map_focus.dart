import 'package:faunawatch/features/feed/models/feed_post.dart';

/// A post's approximate spot to show on the community map.
///
/// The point is always rounded to about 1 km (see [FeedPost.approxLatitude]).
/// A public (approved) post already has a pin there. A post that is not
/// public (the owner's pending or declined post) gets a temporary marker that
/// only the owner sees, since it is drawn on their own device.
class MapFocus {
  const MapFocus({
    required this.postId,
    required this.latitude,
    required this.longitude,
    required this.isPublic,
  });

  final String postId;
  final double latitude, longitude;
  final bool isPublic;

  /// Label of the owner-only marker.
  static const privateLabel = 'Only you can see this';

  /// Null when the post has no location to show.
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
      other.isPublic == isPublic;

  @override
  int get hashCode => Object.hash(postId, latitude, longitude, isPublic);
}
