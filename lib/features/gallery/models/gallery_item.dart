/// Presentation data for one of the signed-in user's approved reports.
class GalleryItem {
  const GalleryItem({
    required this.id,
    this.title = '',
    this.location = '',
    this.date = '',
    this.category = 'All',
    this.imageUrl,
  });

  final String id;
  final String title;
  final String location;
  final String date;
  final String category;

  /// First available signed report photo, refreshed with the gallery page.
  final String? imageUrl;

  GalleryItem copyWith({
    String? id,
    String? title,
    String? location,
    String? date,
    String? category,
    String? imageUrl,
  }) {
    return GalleryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      date: date ?? this.date,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
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
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, location, date, category, imageUrl);
}

/// State container for the Gallery screen.
class GalleryState {
  const GalleryState({
    this.items = const [],
    this.selectedCategory = 'All',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.hasError = false,
    this.isRefreshing = false,
    this.message,
  });

  final List<GalleryItem> items;
  final String selectedCategory;
  final bool isLoading;
  final bool isLoadingMore, hasMore, hasError;
  final bool isRefreshing;
  final String? message;

  /// Returns items filtered by [selectedCategory].
  List<GalleryItem> get filteredItems {
    if (selectedCategory == 'All') return items;
    return items.where((item) => item.category == selectedCategory).toList();
  }

  GalleryState copyWith({
    List<GalleryItem>? items,
    String? selectedCategory,
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
      selectedCategory: selectedCategory ?? this.selectedCategory,
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
        other.selectedCategory == selectedCategory &&
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
    selectedCategory,
    isLoading,
    isLoadingMore,
    hasMore,
    hasError,
    isRefreshing,
    message,
  );
}
