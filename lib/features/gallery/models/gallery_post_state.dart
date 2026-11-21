import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// Which gallery post a viewer page shows, and the status its tile had.
/// Pending and declined posts are not in the public feed, so they load
/// differently from approved ones. A public-gallery author restricts access
/// to that author's approved posts.
typedef GalleryPostRef = ({String id, ReportStatus status, String? authorId});

/// Full post data and action feedback for one profile-gallery page.
class GalleryPostState {
  const GalleryPostState({
    this.post,
    this.isLoading = false,
    this.hasError = false,
    this.status = ReportStatus.approved,
    this.declineReason,
    this.message,
  });

  final FeedPost? post;
  final bool isLoading, hasError;

  /// Approved, pending or declined. Only approved posts are public, so only
  /// they can be liked and commented on.
  final ReportStatus status;

  /// The admin's reason, for a declined post.
  final DeclineReason? declineReason;
  final String? message;

  bool get isPending => status == ReportStatus.pending;
  bool get isDeclined => status == ReportStatus.declined;
  bool get isPublic => status == ReportStatus.approved;

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
    status: status,
    declineReason: declineReason,
    message: clearMessage ? null : message ?? this.message,
  );
}
