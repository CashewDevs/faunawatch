import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// One of the user's own reports loaded for the gallery, with its review
/// status and whether the user hid it.
class GalleryPost {
  const GalleryPost(this.post, this.status, {this.isHidden = false});

  final FeedPost post;
  final ReportStatus status;

  /// Hidden by the user: left out of the feed, the map and the public
  /// profile, and shown here with a "Hidden" badge.
  final bool isHidden;
}
