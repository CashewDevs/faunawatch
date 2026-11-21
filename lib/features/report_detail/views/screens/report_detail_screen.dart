import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/post_comments_sheet.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/viewmodels/report_detail_viewmodel.dart';

/// Shows one of the signed-in user's own reports in any status, with its
/// status stated clearly. Approved reports reuse the feed's post card (photos,
/// likes, comments); other reports show their photos and details.
///
/// With [showComments] the comments sheet opens once an approved report has
/// loaded (used for comment notifications).
class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.reportId,
    this.showComments = false,
  });

  final String reportId;
  final bool showComments;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _commentsShown = false;

  void _openComments() {
    final viewModel = ref.read(
      reportDetailViewModelProvider(widget.reportId).notifier,
    );
    PostCommentsSheet.show(
      context,
      widget.reportId,
      onChanged: viewModel.commentsChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = reportDetailViewModelProvider(widget.reportId);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    ref.listen(provider.select((state) => state.message), (_, message) {
      if (message == null) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      viewModel.clearMessage();
    });
    final report = state.report;
    if (widget.showComments &&
        !_commentsShown &&
        report != null &&
        report.isApproved) {
      _commentsShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openComments();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your report')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasError
          ? _Notice(
              text: 'Could not load this report. Check your connection.',
              actionLabel: 'Try again',
              onAction: viewModel.retry,
            )
          : report == null
          ? const _Notice(
              text:
                  'This report is no longer available. It may have been '
                  'deleted.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBanner(status: report.status),
                Expanded(
                  child: report.isApproved
                      ? FeedPostCard(
                          post: report.post,
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          onLike: viewModel.toggleLike,
                          onComments: _openComments,
                        )
                      : _ReportDetails(report: report),
                ),
              ],
            ),
    );
  }
}

/// Colored line stating the report's status.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (
      Color background,
      Color foreground,
      IconData icon,
    ) = switch (status) {
      ReportStatus.approved => (
        isDark ? AppColors.darkSurface : AppColors.consentBadgeGreenBackground,
        isDark ? AppColors.darkIconGreen : AppColors.consentBadgeGreenText,
        Icons.check_circle_outline,
      ),
      ReportStatus.declined => (
        isDark
            ? AppColors.darkErrorBackground
            : AppColors.consentBadgeRedBackground,
        isDark ? AppColors.darkErrorText : AppColors.consentBadgeRedText,
        Icons.cancel_outlined,
      ),
      ReportStatus.changesRequested => (
        isDark ? AppColors.darkSurface : AppColors.messagesFilterSelected,
        isDark ? AppColors.darkIconOrange : AppColors.profileSelectedOrange,
        Icons.edit_note_rounded,
      ),
      ReportStatus.pending || ReportStatus.other => (
        isDark ? AppColors.darkSurface : AppColors.messagesHeaderGradientStart,
        isDark ? AppColors.darkAccentBlue : AppColors.messagesHeaderBlue,
        Icons.hourglass_empty_rounded,
      ),
    };
    return Semantics(
      container: true,
      label: 'Status: ${status.label}. ${status.description}',
      child: Container(
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    status.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photos and details of a report that is not (or no longer) public.
class _ReportDetails extends StatelessWidget {
  const _ReportDetails({required this.report});
  final OwnReport report;

  @override
  Widget build(BuildContext context) {
    final post = report.post;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 320,
            child: PostImageCarousel.network(
              key: ValueKey(post.id),
              imageUrls: post.photoUrls,
              fit: BoxFit.cover,
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${post.categoryLabel} · ${post.location}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (post.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(post.description, style: theme.textTheme.bodyMedium),
                ],
              ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
