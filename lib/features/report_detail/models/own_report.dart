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

/// Why an admin declined (or took down) a report, from the
/// `decline_reason` database enum. Labels match the reporter's notification.
enum DeclineReason {
  inaccurateSpecies('inaccurate_species', 'Inaccurate species'),
  lowQualityPhoto('low_quality_photo', 'Low-quality photo'),
  domesticSpecimen('domestic_specimen', 'Domestic specimen'),
  duplicate('duplicate', 'Duplicate report'),
  inaccurateGps('inaccurate_gps', 'Inaccurate GPS location'),
  inappropriateContent('inappropriate_content', 'Inappropriate content'),
  notWildlife('not_wildlife', 'Not about wildlife');

  const DeclineReason(this.value, this.label);
  final String value;
  final String label;

  /// Null for a missing or unknown reason.
  static DeclineReason? fromDb(Object? value) {
    for (final reason in values) {
      if (reason.value == value) return reason;
    }
    return null;
  }
}

/// One of the signed-in user's own reports, in any status.
///
/// [post] reuses the feed's post model (title, category, place, photos);
/// likes and comments are only meaningful once the report is approved.
class OwnReport {
  const OwnReport({
    required this.post,
    required this.status,
    this.declineReason,
  });
  final FeedPost post;
  final ReportStatus status;

  /// The admin's latest reason, only for a declined report.
  final DeclineReason? declineReason;

  bool get isApproved => status == ReportStatus.approved;

  OwnReport copyWith({FeedPost? post}) => OwnReport(
    post: post ?? this.post,
    status: status,
    declineReason: declineReason,
  );
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
