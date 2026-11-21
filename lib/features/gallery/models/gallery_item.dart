import 'package:faunawatch/features/gallery/models/gallery_filter.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

export 'package:faunawatch/features/gallery/models/gallery_filter.dart';
export 'package:faunawatch/features/report_detail/models/own_report.dart'
    show ReportStatus;

/// Presentation data for one of the signed-in user's approved or pending
/// reports.
class GalleryItem {
  const GalleryItem({
    required this.id,
    this.title = '',
    this.location = '',
    this.date = '',
    this.category = 'All',
    this.imageUrl,
    this.status = ReportStatus.approved,
  });

  final String id;
  final String title;
  final String location;
  final String date;
  final String category;

  /// First available signed report photo, refreshed with the gallery page.
  final String? imageUrl;

  /// Approved or pending; pending tiles carry a "Pending review" badge.
  final ReportStatus status;

  bool get isPending => status == ReportStatus.pending;

  GalleryItem copyWith({
    String? id,
    String? title,
    String? location,
    String? date,
    String? category,
    String? imageUrl,
    ReportStatus? status,
  }) {
    return GalleryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      date: date ?? this.date,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GalleryItem &&
        other.id == id &&
        other.title == title &&
        other.location == location &&
        other.date == date &&
        other.category == category &&
        other.imageUrl == imageUrl &&
        other.status == status;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, location, date, category, imageUrl, status);
}

/// State container for the Gallery screen.
class GalleryState {
  const GalleryState({
    this.items = const [],
    this.filter = const GalleryFilter(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.hasError = false,
    this.isRefreshing = false,
    this.message,
  });

  /// The loaded tiles; the server already applied [filter].
  final List<GalleryItem> items;
  final GalleryFilter filter;
  final bool isLoading;
  final bool isLoadingMore, hasMore, hasError;
  final bool isRefreshing;
  final String? message;

  /// Title and hint shown when the current filter has no posts.
  ({String title, String hint}) get emptyMessage {
    if (filter.category != null) {
      return (title: 'No posts in this category.', hint: 'Try another filter.');
    }
    return switch (filter.status) {
      GalleryStatusFilter.all => (
        title: 'No posts yet.',
        hint: 'Your approved and pending posts will appear here.',
      ),
      GalleryStatusFilter.pending => (
        title: 'Nothing waiting for review.',
        hint: 'New posts stay here until an admin reviews them.',
      ),
      GalleryStatusFilter.approved => (
        title: 'No approved posts yet.',
        hint: 'Posts appear here once an admin approves them.',
      ),
    };
  }

  GalleryState copyWith({
    List<GalleryItem>? items,
    GalleryFilter? filter,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? hasError,
    bool? isRefreshing,
    String? message,
    bool clearMessage = false,
  }) {
    return GalleryState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      hasError: hasError ?? this.hasError,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GalleryState &&
        other.items == items &&
        other.filter == filter &&
        other.isLoading == isLoading &&
        other.isLoadingMore == isLoadingMore &&
        other.hasMore == hasMore &&
        other.hasError == hasError &&
        other.isRefreshing == isRefreshing &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(
    items,
    filter,
    isLoading,
    isLoadingMore,
    hasMore,
    hasError,
    isRefreshing,
    message,
  );
}
