import 'dart:async';

import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/models/gallery_filter.dart';
import 'package:faunawatch/features/gallery/models/gallery_post.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// Filters like the database: by [statuses] (approved when missing), by
/// category and, for the Hidden chip, by [hidden]; newest first in [posts]
/// order.
class FakeGalleryService implements GalleryService {
  FakeGalleryService({
    List<FeedPost> posts = const [],
    Map<String, ReportStatus>? statuses,
    Set<String>? hidden,
  }) : posts = [...posts],
       statuses = statuses ?? {},
       hidden = hidden ?? {};

  List<FeedPost> posts;

  /// Posts the gallery never lists (e.g. only the feed knows them).
  List<FeedPost> unlisted = [];
  final Map<String, ReportStatus> statuses;

  /// Ids of posts the user hid.
  final Set<String> hidden;

  /// The `before` and filter of every page request, in order.
  final pageRequests = <FeedPost?>[];
  final filterRequests = <GalleryFilter>[];
  Object? pageError;

  /// While set, pages wait for it.
  Completer<void>? pageGate;

  ReportStatus statusOf(String id) => statuses[id] ?? ReportStatus.approved;

  @override
  Future<List<GalleryPost>> fetchPage({
    GalleryFilter filter = const GalleryFilter(),
    FeedPost? before,
  }) async {
    pageRequests.add(before);
    filterRequests.add(filter);
    await pageGate?.future;
    if (pageError != null) throw pageError!;
    final matching = [
      for (final post in posts)
        if (filter.status.statuses.contains(statusOf(post.id)) &&
            (!filter.status.onlyHidden || hidden.contains(post.id)) &&
            (filter.category == null || post.category == filter.category))
          post,
    ];
    final start = before == null
        ? 0
        : matching.indexWhere((post) => post.id == before.id) + 1;
    return [
      for (final post in matching.skip(start).take(GalleryService.pageSize))
        GalleryPost(
          post,
          statusOf(post.id),
          isHidden: hidden.contains(post.id),
        ),
    ];
  }
}
