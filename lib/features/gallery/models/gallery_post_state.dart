import 'package:faunawatch/features/feed/models/feed_post.dart';

/// Full post data and action feedback for one profile-gallery page.
class GalleryPostState {
  const GalleryPostState({
    this.post,
    this.isLoading = false,
    this.hasError = false,
    this.message,
  });

  final FeedPost? post;
  final bool isLoading, hasError;
  final String? message;

  GalleryPostState copyWith({
    FeedPost? post,
    bool? isLoading,
    bool? hasError,
    String? message,
    bool clearMessage = false,
  }) => GalleryPostState(
    post: post ?? this.post,
    isLoading: isLoading ?? this.isLoading,
    hasError: hasError ?? this.hasError,
    message: clearMessage ? null : message ?? this.message,
  );
}
