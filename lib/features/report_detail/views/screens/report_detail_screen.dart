import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_result_cards.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/post_comments_sheet.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/viewmodels/report_detail_viewmodel.dart';

/// Shows one of the signed-in user's own reports in any status, with its
/// status stated clearly. Approved reports reuse the feed's post card (photos,
/// likes, comments); other reports show their full-size swipeable photos,
/// details, and a prominent status notice card.
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
    final colors = FaunaLensTheme.of(context);
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.statusBar,
      child: Scaffold(
        backgroundColor: colors.page,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FaunaLensPageHeader(
              title: 'Your report',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.hasError
                  ? _Notice(
                      text:
                          'Could not load this report. Check your connection.',
                      actionLabel: 'Try again',
                      onAction: viewModel.retry,
                    )
                  : report == null
                  ? const _Notice(
                      text:
                          'This report is no longer available. It may have been '
                          'deleted.',
                    )
                  : report.isApproved
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: _StatusNoticeCard(status: report.status),
                        ),
                        Expanded(
                          child: FeedPostCard(
                            post: report.post,
                            backgroundColor: colors.page,
                            onLike: viewModel.toggleLike,
                            onComments: _openComments,
                          ),
                        ),
                      ],
                    )
                  : _ReportDetails(report: report),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent, high-visibility status card stating the report's review state.
class _StatusNoticeCard extends StatelessWidget {
  const _StatusNoticeCard({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (
      Color background,
      Color borderColor,
      Color iconBg,
      Color foreground,
      IconData icon,
    ) = switch (status) {
      ReportStatus.approved => (
        isDark ? AppColors.darkSurface : AppColors.consentBadgeGreenBackground,
        isDark ? AppColors.darkIconGreen : AppColors.consentBadgeGreenText,
        isDark ? AppColors.darkIconGreen.withValues(alpha: 0.2) : Colors.white,
        isDark ? AppColors.darkIconGreen : AppColors.consentBadgeGreenText,
        Icons.check_circle_outline_rounded,
      ),
      ReportStatus.declined => (
        isDark
            ? AppColors.darkErrorBackground
            : AppColors.consentBadgeRedBackground,
        isDark ? AppColors.darkErrorText : AppColors.consentBadgeRedText,
        isDark ? AppColors.darkErrorText.withValues(alpha: 0.18) : Colors.white,
        isDark ? AppColors.darkErrorText : AppColors.consentBadgeRedText,
        Icons.cancel_outlined,
      ),
      ReportStatus.changesRequested => (
        isDark
            ? AppColors.darkFilterSelected
            : AppColors.messagesFilterSelected,
        isDark ? AppColors.darkIconOrange : AppColors.profileSelectedOrange,
        isDark ? AppColors.darkIconOrange.withValues(alpha: 0.2) : Colors.white,
        isDark ? AppColors.darkIconOrange : AppColors.profileSelectedOrange,
        Icons.edit_note_rounded,
      ),
      ReportStatus.pending || ReportStatus.other => (
        isDark
            ? AppColors.darkFilterSelected
            : AppColors.galleryFilterButtonBackground,
        isDark ? AppColors.darkAccentBlue : AppColors.faunaLensBlue,
        isDark
            ? AppColors.darkAccentBlue.withValues(alpha: 0.2)
            : AppColors.faunaLensYellow,
        isDark ? AppColors.darkAccentBlue : AppColors.faunaLensBlue,
        Icons.hourglass_top_rounded,
      ),
    };

    final bodyColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.consentTitleNavy;

    return Semantics(
      container: true,
      label: 'Status: ${status.label}. ${status.description}',
      child: Container(
        key: const ValueKey('report_detail_status_card'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: foreground, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: GoogleFonts.dmSans(
                      color: foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.description,
                    style: GoogleFonts.dmSans(
                      color: bodyColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
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

/// Full-size swipeable photos, report title/name, details, and prominent
/// review notice for a report that is not (or no longer) public.
class _ReportDetails extends StatelessWidget {
  const _ReportDetails({required this.report});
  final OwnReport report;

  @override
  Widget build(BuildContext context) {
    final post = report.post;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoHeight = (MediaQuery.sizeOf(context).height * 0.56).clamp(
      380.0,
      540.0,
    );
    final photoBackdrop = isDark
        ? AppColors.darkSurface
        : const Color(0xFFF3F6FA);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const ValueKey('report_detail_photo_container'),
              height: photoHeight,
              child: PostImageCarousel.network(
                key: ValueKey(post.id),
                imageUrls: post.photoUrls,
                fit: BoxFit.contain,
                backgroundColor: photoBackdrop,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: GoogleFonts.dmSans(
                      color: isDark ? Colors.white : AppColors.consentTitleNavy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${post.categoryLabel} · ${post.location}',
                          style: GoogleFonts.dmSans(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (post.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      post.description,
                      style: GoogleFonts.dmSans(
                        color: isDark
                            ? AppColors.darkTextBody
                            : AppColors.consentBodyText,
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _StatusNoticeCard(status: report.status),
                ],
              ),
            ),
          ],
        ),
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
