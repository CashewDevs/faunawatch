import 'post_draft.dart';

/// A confirmed observation point, with a friendly label for the form.
class PostLocation {
  const PostLocation({
    required this.latitude,
    required this.longitude,
    this.label = 'Pinned location',
  });
  final double latitude, longitude;
  final String label;
  bool get isValid => PostDraft.validCoordinates(latitude, longitude);
}
