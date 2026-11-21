import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';

/// Public identity and approved posts for one account. No private form data.
class PublicProfileState {
  const PublicProfileState({
    this.profile,
    this.posts = const [],
    this.category,
    this.isLoading = false,
    this.hasError = false,
    this.isLoadingPosts = false,
    this.postsHaveError = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.message,
  });

  final ProfileData? profile;
  final List<FeedPost> posts;
  final ReportCategory? category;
  final bool isLoading, hasError, isLoadingPosts, postsHaveError;
  final bool isLoadingMore, hasMore;
  final String? message;

  PublicProfileState copyWith({
    ProfileData? profile,
    List<FeedPost>? posts,
    ReportCategory? category,
    bool clearCategory = false,
    bool? isLoading,
    bool? hasError,
    bool? isLoadingPosts,
    bool? postsHaveError,
    bool? isLoadingMore,
    bool? hasMore,
    String? message,
    bool clearMessage = false,
  }) => PublicProfileState(
    profile: profile ?? this.profile,
    posts: posts ?? this.posts,
    category: clearCategory ? null : category ?? this.category,
    isLoading: isLoading ?? this.isLoading,
    hasError: hasError ?? this.hasError,
    isLoadingPosts: isLoadingPosts ?? this.isLoadingPosts,
    postsHaveError: postsHaveError ?? this.postsHaveError,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    message: clearMessage ? null : message ?? this.message,
  );
}
