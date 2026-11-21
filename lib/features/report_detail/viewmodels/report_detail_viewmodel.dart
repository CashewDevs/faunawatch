import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';

/// Loads one of the user's own reports by id (any status). For an approved
/// report it also loads likes and comment counts through [FeedService] and
/// manages local likes. Rebuilds, discarding old results, on account changes.
class ReportDetailViewModel
    extends AutoDisposeFamilyNotifier<ReportDetailState, String> {
  late ReportDetailService _service;
  late FeedService _feed;
  int _generation = 0;
  bool _liking = false;
  bool _disposed = false;

  @override
  ReportDetailState build(String arg) {
    _service = ref.watch(reportDetailServiceProvider);
    _feed = ref.watch(feedServiceProvider);
    final generation = ++_generation;
    _liking = false;
    _disposed = false;
    ref.onDispose(() {
      _generation++;
      _disposed = true;
    });
    Future.microtask(() => _load(generation));
    return const ReportDetailState(isLoading: true);
  }

  Future<void> _load(int generation) async {
    if (generation != _generation) return;
    try {
      var report = await _service.fetchOwnReport(arg);
      if (generation != _generation) return;
      if (report != null && report.isApproved) {
        // Engagement (likes, comment count) comes from the feed; if that
        // fails the report is still shown without it.
        try {
          final feedPost = await _feed.fetchPost(arg);
          if (generation != _generation) return;
          if (feedPost != null) {
            report = report.copyWith(
              post: feedPost.copyWith(photoUrls: report.post.photoUrls),
            );
          }
        } catch (_) {
          if (generation != _generation) return;
        }
      }
      state = ReportDetailState(report: report);
    } catch (_) {
      if (generation == _generation) {
        state = const ReportDetailState(hasError: true);
      }
    }
  }

  Future<void> retry() async {
    if (state.isLoading) return;
    state = const ReportDetailState(isLoading: true);
    await _load(++_generation);
  }

  Future<void> toggleLike() async {
    final report = state.report;
    if (report == null || !report.isApproved || _liking) return;
    final before = report.post;
    _liking = true;
    final generation = _generation;
    final liked = !before.likedByMe;
    state = state.copyWith(
      report: report.copyWith(
        post: before.copyWith(
          likedByMe: liked,
          likeCount: math.max(0, before.likeCount + (liked ? 1 : -1)),
        ),
      ),
    );
    try {
      await (liked ? _feed.like(arg) : _feed.unlike(arg));
    } catch (_) {
      if (generation == _generation) {
        final current = state.report;
        state = state.copyWith(
          report: current?.copyWith(
            post: current.post.copyWith(
              likedByMe: before.likedByMe,
              likeCount: before.likeCount,
            ),
          ),
          message: 'Could not update your like.',
        );
      }
    } finally {
      if (generation == _generation) _liking = false;
    }
  }

  /// The comments sheet owns its requests; this keeps the local count in step,
  /// preserving larger totals when only the latest 100 are loaded.
  void commentsChanged(PostCommentsState? previous, PostCommentsState next) {
    if (_disposed) return;
    final report = state.report;
    if (report == null || next.isLoading || next.hasError) return;
    final post = report.post;
    if (next.comments.length < FeedService.commentLimit) {
      state = state.copyWith(
        report: report.copyWith(
          post: post.copyWith(commentCount: next.comments.length),
        ),
      );
    } else if (previous != null &&
        previous.isSending &&
        !next.isSending &&
        next.sendError == null &&
        next.comments.length > previous.comments.length) {
      state = state.copyWith(
        report: report.copyWith(
          post: post.copyWith(
            commentCount:
                post.commentCount +
                next.comments.length -
                previous.comments.length,
          ),
        ),
      );
    }
  }

  void clearMessage() => state = state.copyWith(clearMessage: true);
}

final reportDetailViewModelProvider = NotifierProvider.autoDispose
    .family<ReportDetailViewModel, ReportDetailState, String>(
      ReportDetailViewModel.new,
    );
