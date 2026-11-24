import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// The status chips under the My Gallery title.
enum GalleryStatusFilter {
  all('All', [
    ReportStatus.approved,
    ReportStatus.pending,
    ReportStatus.declined,
  ]),
  pending('Pending', [ReportStatus.pending]),
  approved('Approved', [ReportStatus.approved]),
  declined('Declined', [ReportStatus.declined]),

  /// Posts the user hid, in any status. Only the owner sees this chip.
  hidden('Hidden', [
    ReportStatus.approved,
    ReportStatus.pending,
    ReportStatus.declined,
  ], onlyHidden: true);

  const GalleryStatusFilter(
    this.label,
    this.statuses, {
    this.onlyHidden = false,
  });
  final String label;

  /// Report statuses this chip shows. Changes-requested reports are never
  /// part of the gallery.
  final List<ReportStatus> statuses;

  /// Shows only hidden posts. The other chips show hidden posts too, with a
  /// "Hidden" badge.
  final bool onlyHidden;
}

/// The gallery's status chip and optional category, applied by the server.
class GalleryFilter {
  const GalleryFilter({this.status = GalleryStatusFilter.all, this.category});

  final GalleryStatusFilter status;

  /// `null` shows every category.
  final ReportCategory? category;

  GalleryFilter copyWith({
    GalleryStatusFilter? status,
    ReportCategory? category,
    bool clearCategory = false,
  }) {
    return GalleryFilter(
      status: status ?? this.status,
      category: clearCategory ? null : category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GalleryFilter &&
      other.status == status &&
      other.category == category;

  @override
  int get hashCode => Object.hash(status, category);
}
