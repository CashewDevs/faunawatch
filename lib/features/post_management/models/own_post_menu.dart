import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// One of the user's own posts, as the "⋯" menu needs it: which status it
/// has and whether it is hidden decide what the menu offers.
class OwnPostMenu {
  const OwnPostMenu({
    required this.postId,
    required this.status,
    this.isHidden = false,
  });

  final String postId;
  final ReportStatus status;
  final bool isHidden;

  /// Only approved posts are public, so only they can be hidden.
  bool get canHide => !isHidden && status == ReportStatus.approved;

  /// A hidden post can be shown again in any status.
  bool get canUnhide => isHidden;
}

/// Why a hide, unhide or delete did not happen.
enum PostActionFailure {
  /// The post no longer exists, or isn't the user's.
  notFound('This post is no longer available.'),

  /// Only approved posts can be hidden.
  notPublic('Only approved posts can be hidden.'),

  unknown('Something went wrong. Check your connection and try again.');

  const PostActionFailure(this.message);
  final String message;
}

class PostActionException implements Exception {
  const PostActionException(this.failure);
  final PostActionFailure failure;

  @override
  String toString() => 'PostActionException(${failure.name})';
}
