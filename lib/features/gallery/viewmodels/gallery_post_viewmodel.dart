import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/gallery/models/gallery_post_state.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';

export 'package:faunawatch/features/gallery/models/gallery_post_state.dart';

/// Loads a full gallery post and manages its actions without changing feed state
/// or the shell destination. All account changes discard the previous result.
///
/// Approved posts load from the public feed (with likes and comments). Pending
/// and declined posts are not in it, so they load through the owner's own
/// report access and keep likes and comments closed. A declined post also
/// carries the admin's reason.
class GalleryPostViewModel
    extends AutoDisposeFamilyNotifier<GalleryPostState, GalleryPostRef> {
  late FeedService _service;
  String? _ownerId;
  int _generation = 0;
  bool _liking = false;
  bool _disposed = false;

  @override
  GalleryPostState build(GalleryPostRef arg) {
    _service = ref.watch(feedServiceProvider);
    _ownerId = ref.watch(currentUserIdProvider).valueOrNull;
    final generation = ++_generation;
    _liking = false;
    _disposed = false;
    ref.onDispose(() {
      _generation++;
      _disposed = true;
    });
    Future.microtask(() => _load(generation));
    return const GalleryPostState(isLoading: true);
  }

  Future<void> _load(int generation) async {
    if (generation != _generation) return;
    final ownerId = _ownerId;
    if (ownerId == null) {
      state = const GalleryPostState();
      return;
    }
    try {
      if (arg.status != ReportStatus.approved) {
        // Public galleries never read pending or declined owner reports.
        if (arg.authorId != null) {
          state = const GalleryPostState();
          return;
        }
        // Account changes rebuild this ViewModel, so reading is enough.
        final report = await ref
            .read(reportDetailServiceProvider)
            .fetchOwnReport(arg.id);
        if (generation != _generation) return;
        final status = report?.status;
        if (status == ReportStatus.pending || status == ReportStatus.declined) {
          final post = await _withOwnProfile(report!.post);
          if (generation != _generation) return;
          state = GalleryPostState(
            post: post,
            status: status!,
            declineReason: report.declineReason,
          );
          return;
        }
        // Reviewed since the gallery loaded: an approval loads from the feed,
        // and a change request is no longer part of the gallery.
        if (status != ReportStatus.approved) {
          state = const GalleryPostState();
          return;
        }
      }
      final post = await _service.fetchPost(arg.id);
      if (generation != _generation) return;
      state = GalleryPostState(
        post: post?.authorId == (arg.authorId ?? ownerId) ? post : null,
      );
    } catch (_) {
      if (generation == _generation) {
        state = const GalleryPostState(hasError: true);
      }
    }
  }

  /// Shows the owner's own name and picture, which the report itself lacks.
  /// Without a profile the report's placeholder author stays.
  Future<FeedPost> _withOwnProfile(FeedPost post) async {
    try {
      final profile = await ref.read(profileViewModelProvider.future);
      final name = profile.username.trim();
      return post.copyWith(
        authorName: name.isEmpty ? null : name,
        authorAvatarAsset: profile.presetAvatar,
        authorAvatarUrl: profile.avatarUrl,
      );
    } catch (_) {
      return post;
    }
  }

  Future<void> retry() async {
    if (state.isLoading) return;
    state = const GalleryPostState(isLoading: true);
    await _load(++_generation);
  }

  Future<void> toggleLike() async {
    final before = state.post;
    if (before == null || _liking || !state.isPublic) return;
    _liking = true;
    final generation = _generation;
    final liked = !before.likedByMe;
    state = state.copyWith(
      post: before.copyWith(
        likedByMe: liked,
        likeCount: math.max(0, before.likeCount + (liked ? 1 : -1)),
      ),
    );
    try {
      await (liked ? _service.like(arg.id) : _service.unlike(arg.id));
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          post: state.post?.copyWith(
            likedByMe: before.likedByMe,
            likeCount: before.likeCount,
          ),
          message: 'Could not update your like.',
        );
      }
    } finally {
      if (generation == _generation) _liking = false;
    }
  }

  /// The sheet owns comment requests; this viewer keeps its local count in
  /// step, preserving larger totals when only the latest 100 are loaded.
  void commentsChanged(PostCommentsState? previous, PostCommentsState next) {
    if (_disposed) return;
    final post = state.post;
    if (post == null || next.isLoading || next.hasError) return;
    if (next.comments.length < FeedService.commentLimit) {
      state = state.copyWith(
        post: post.copyWith(commentCount: next.comments.length),
      );
    } else if (previous != null &&
        previous.isSending &&
        !next.isSending &&
        next.sendError == null &&
        next.comments.length > previous.comments.length) {
      state = state.copyWith(
        post: post.copyWith(
          commentCount:
              post.commentCount +
              next.comments.length -
              previous.comments.length,
        ),
      );
    }
  }

  void clearMessage() => state = state.copyWith(clearMessage: true);
}

final galleryPostViewModelProvider = NotifierProvider.autoDispose
    .family<GalleryPostViewModel, GalleryPostState, GalleryPostRef>(
      GalleryPostViewModel.new,
    );
