import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/feed/viewmodels/post_comments_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/comment_input_bar.dart';
import 'package:faunawatch/features/feed/views/widgets/comment_tile.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';

/// Bottom sheet listing a post's comments, newest first, with a composer.
///
/// Comments are plain text: `report_comments` has no replies, reactions or
/// photo attachments, so the sheet offers none, and there is no "top" sort.
class PostCommentsSheet extends ConsumerWidget {
  const PostCommentsSheet({super.key, required this.postId});
  final String postId;

  static Future<void> show(BuildContext context, String postId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PostCommentsSheet(postId: postId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = postCommentsViewModelProvider(postId);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    final profile = ref.watch(profileViewModelProvider).asData?.value;
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SizedBox(
        height: mediaQuery.size.height * 0.72,
        child: Column(
          children: [
            _SheetHeader(count: state.comments.length),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.hasError
                  ? _Notice(
                      text: 'Could not load comments.',
                      actionLabel: 'Retry',
                      onAction: viewModel.load,
                    )
                  : state.comments.isEmpty
                  ? const _Notice(text: 'No comments yet. Be the first!')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
                      itemCount: state.comments.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: CommentTile(comment: state.comments[index]),
                      ),
                    ),
            ),
            if (state.sendError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  state.sendError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
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
              isSending: state.isSending,
              onSubmit: viewModel.addComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$count ${count == 1 ? 'comment' : 'comments'}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
