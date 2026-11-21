import 'package:faunawatch/features/feed/models/feed_post.dart';

/// Moderation status of a report, from `reports.status`.
enum ReportStatus {
  pending('Pending review', 'An admin has not reviewed this report yet.'),
  changesRequested(
    'Changes requested',
    'An admin asked for changes. Update the report and resubmit it.',
  ),
  approved('Approved', 'This report is visible to the community.'),
  declined('Declined', 'This report was not approved and is not public.'),

  /// A status this app version does not know (e.g. the legacy `submitted`).
  other('Submitted', 'This report has been submitted.');

  const ReportStatus(this.label, this.description);
  final String label;
  final String description;

  static ReportStatus fromDb(String? value) {
    switch (value) {
      case 'pending':
        return ReportStatus.pending;
      case 'changes_requested':
        return ReportStatus.changesRequested;
      case 'approved':
        return ReportStatus.approved;
      case 'declined':
        return ReportStatus.declined;
      default:
        return ReportStatus.other;
    }
  }
}

/// One of the signed-in user's own reports, in any status.
///
/// [post] reuses the feed's post model (title, category, place, photos);
/// likes and comments are only meaningful once the report is approved.
class OwnReport {
  const OwnReport({required this.post, required this.status});
  final FeedPost post;
  final ReportStatus status;

  bool get isApproved => status == ReportStatus.approved;

  OwnReport copyWith({FeedPost? post}) =>
      OwnReport(post: post ?? this.post, status: status);
}

/// State of the single-report screen. When nothing is loading, there is no
/// error and [report] is null, the report does not exist (any more) for this
/// user.
class ReportDetailState {
  const ReportDetailState({
    this.report,
    this.isLoading = false,
    this.hasError = false,
    this.message,
  });

  final OwnReport? report;
  final bool isLoading, hasError;
  final String? message;

  bool get notFound => !isLoading && !hasError && report == null;

  ReportDetailState copyWith({
    OwnReport? report,
    bool? isLoading,
    bool? hasError,
    String? message,
    bool clearMessage = false,
  }) => ReportDetailState(
    report: report ?? this.report,
    isLoading: isLoading ?? this.isLoading,
    hasError: hasError ?? this.hasError,
    message: clearMessage ? null : message ?? this.message,
  );
}
