import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// One of the user's own reports loaded for the gallery, with its review status.
class GalleryPost {
  const GalleryPost(this.post, this.status);

  final FeedPost post;
  final ReportStatus status;
}
