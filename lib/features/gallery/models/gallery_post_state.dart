import 'package:faunawatch/features/feed/models/feed_post.dart';

/// Which gallery post a viewer page shows, and whether it is still pending
/// (pending posts are not in the public feed, so they load differently).
typedef GalleryPostRef = ({String id, bool isPending});

/// Full post data and action feedback for one profile-gallery page.
class GalleryPostState {
  const GalleryPostState({
    this.post,
    this.isLoading = false,
    this.hasError = false,
    this.isPending = false,
    this.message,
  });

  final FeedPost? post;
  final bool isLoading, hasError;

  /// Still waiting for an admin; likes and comments are not open yet.
  final bool isPending;
  final String? message;

  GalleryPostState copyWith({
    FeedPost? post,
    bool? isLoading,
    bool? hasError,
    bool? isPending,
    String? message,
    bool clearMessage = false,
  }) => GalleryPostState(
    post: post ?? this.post,
    isLoading: isLoading ?? this.isLoading,
    hasError: hasError ?? this.hasError,
    isPending: isPending ?? this.isPending,
    message: clearMessage ? null : message ?? this.message,
  );
}
