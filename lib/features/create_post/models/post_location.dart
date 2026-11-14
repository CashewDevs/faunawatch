import 'post_draft.dart';

/// A confirmed observation point, with a friendly label for the form.
class PostLocation {
  /// Camera fallback only; never selects an observation point for the user.
  static const regionalFallback = PostLocation(latitude: 12, longitude: 122);

  const PostLocation({
    required this.latitude,
    required this.longitude,
    this.label = 'Pinned location',
  });
  final double latitude, longitude;
  final String label;
  bool get isValid => PostDraft.validCoordinates(latitude, longitude);
}
