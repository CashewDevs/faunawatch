import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:faunawatch/features/post_management/services/post_management_service.dart';
import 'package:faunawatch/features/report_detail/viewmodels/report_detail_viewmodel.dart';

/// The answer to a post action: [done], or [error] to show the user. Neither
/// is set when the tap was ignored because the same post is still busy.
typedef PostActionResult = ({bool done, String? error});

/// Hides, shows and deletes the user's own posts, then brings every screen
/// that shows the post up to date: the Feed, My Gallery, the map and the
/// "Your report" screen. Its state is the set of posts with an action
/// running; a second tap on such a post is ignored.
class PostActionsViewModel extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // A new account starts with nothing running.
    ref.watch(currentUserIdProvider);
    return const {};
  }

  /// Hides an approved post ([hidden] true) or shows a hidden one again.
  Future<PostActionResult> setHidden(String postId, {required bool hidden}) =>
      _run(postId, () async {
        await ref
            .read(postManagementServiceProvider)
            .setHidden(postId, hidden: hidden);
        // Only screens already loaded are updated; nothing is started for it.
        if (ref.exists(feedViewModelProvider)) {
          final feed = ref.read(feedViewModelProvider.notifier);
          // A shown post comes back in its place in the feed's order.
          hidden ? feed.removePost(postId) : unawaited(feed.refresh());
        }
        if (ref.exists(galleryViewModelProvider)) {
          ref
              .read(galleryViewModelProvider.notifier)
              .postHiddenChanged(postId, hidden: hidden);
        }
        _refreshMapAndDetail(postId);
      });

  /// Deletes the post for good.
  Future<PostActionResult> delete(String postId) => _run(postId, () async {
    await ref.read(postManagementServiceProvider).delete(postId);
    if (ref.exists(feedViewModelProvider)) {
      ref.read(feedViewModelProvider.notifier).removePost(postId);
    }
    if (ref.exists(galleryViewModelProvider)) {
      ref.read(galleryViewModelProvider.notifier).postDeleted(postId);
    }
    _refreshMapAndDetail(postId);
  });

  Future<PostActionResult> _run(
    String postId,
    Future<void> Function() action,
  ) async {
    if (state.contains(postId)) return (done: false, error: null);
    state = {...state, postId};
    try {
      await action();
      return (done: true, error: null);
    } on PostActionException catch (error) {
      return (done: false, error: error.failure.message);
    } catch (_) {
      return (done: false, error: PostActionFailure.unknown.message);
    } finally {
      state = {...state}..remove(postId);
    }
  }

  void _refreshMapAndDetail(String postId) {
    if (ref.exists(communityMapViewModelProvider)) {
      unawaited(
        ref.read(communityMapViewModelProvider.notifier).refreshReports(),
      );
    }
    // An open "Your report" screen loads the post again (a deleted one then
    // says it is no longer available).
    if (ref.exists(reportDetailViewModelProvider(postId))) {
      ref.invalidate(reportDetailViewModelProvider(postId));
    }
  }
}

final postActionsViewModelProvider =
    NotifierProvider<PostActionsViewModel, Set<String>>(
      PostActionsViewModel.new,
    );
