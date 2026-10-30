import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/viewmodels/post_comments_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/comment_input_bar.dart';
import 'package:faunawatch/features/feed/views/widgets/comment_tile.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';

/// Bottom sheet listing a post's comments, with threaded replies and a composer.
class PostCommentsSheet extends ConsumerStatefulWidget {
  const PostCommentsSheet({super.key, required this.post});
  final FeedPost post;

  static Future<void> show(BuildContext context, FeedPost post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PostCommentsSheet(post: post),
    );
  }

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  final _expandedCommentIds = <String>{};
  PostComment? _replyingTo;
  String? _replyParentId;

  PostCommentsViewModel get _viewModel =>
      ref.read(postCommentsViewModelProvider(widget.post.id).notifier);

  Future<bool> _submit(String text, String? imagePath) async {
    final parentId = _replyParentId;
    final posted = await _viewModel.addComment(
      text,
      parentId: parentId,
      imagePath: imagePath,
    );
    if (posted && mounted) {
      setState(() {
        if (parentId != null) _expandedCommentIds.add(parentId);
        _replyingTo = null;
        _replyParentId = null;
      });
    }
    return posted;
  }

  void _startReply(PostComment comment, String parentId) {
    setState(() {
      _replyingTo = comment;
      _replyParentId = parentId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postCommentsViewModelProvider(widget.post.id));
    final profile = ref.watch(profileViewModelProvider).asData?.value;
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SizedBox(
        height: mediaQuery.size.height * 0.72,
        child: Column(
          children: [
            _SheetHeader(
              count: state.totalCount,
              sortOrder: state.sortOrder,
              onSortSelected: _viewModel.setSortOrder,
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.comments.isEmpty
                  ? const _EmptyComments()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
                      itemCount: state.comments.length,
                      itemBuilder: (context, index) => _buildThread(
                        state.comments[index],
                        Theme.of(context),
                      ),
                    ),
            ),
            CommentInputBar(
              avatar: PostAvatar(
                size: 40,
                asset: profile?.presetAvatar,
                filePath: profile?.customImagePath,
                url: profile?.avatarUrl,
              ),
              replyingTo: _replyingTo?.authorName,
              onCancelReply: () => setState(() {
                _replyingTo = null;
                _replyParentId = null;
              }),
              onSubmit: _submit,
              onPickImage: _viewModel.pickImage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThread(PostComment comment, ThemeData theme) {
    final isExpanded = _expandedCommentIds.contains(comment.id);
    // Like the reference design, a creator's reply stays visible when collapsed.
    final visibleReplies = isExpanded
        ? comment.replies
        : comment.replies.where((reply) => reply.isFromCreator).take(1);
    final hiddenCount = comment.replies.length - visibleReplies.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTile(comment, comment.id, 44),
          for (final reply in visibleReplies)
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 12),
              child: _buildTile(reply, comment.id, 28),
            ),
          if (hiddenCount > 0 || (isExpanded && comment.replies.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 8),
              child: GestureDetector(
                onTap: () => setState(() {
                  isExpanded
                      ? _expandedCommentIds.remove(comment.id)
                      : _expandedCommentIds.add(comment.id);
                }),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isExpanded
                            ? 'Hide replies'
                            : 'View $hiddenCount '
                                  '${hiddenCount == 1 ? 'reply' : 'replies'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTile(PostComment comment, String parentId, double avatarSize) {
    return CommentTile(
      comment: comment,
      post: widget.post,
      avatarSize: avatarSize,
      onReply: () => _startReply(comment, parentId),
      onLike: () => _viewModel.toggleLike(comment.id),
      onDislike: () => _viewModel.toggleDislike(comment.id),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.count,
    required this.sortOrder,
    required this.onSortSelected,
  });

  final int count;
  final CommentSortOrder sortOrder;
  final ValueChanged<CommentSortOrder> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count ${count == 1 ? 'comment' : 'comments'}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              PopupMenuButton<CommentSortOrder>(
                tooltip: 'Sort comments',
                initialValue: sortOrder,
                onSelected: onSortSelected,
                icon: const Icon(Icons.filter_list, size: 20),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: CommentSortOrder.top,
                    child: Text('Top comments'),
                  ),
                  PopupMenuItem(
                    value: CommentSortOrder.newest,
                    child: Text('Newest first'),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 8,
            child: IconButton.filledTonal(
              tooltip: 'Close comments',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'No comments yet. Be the first!',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
