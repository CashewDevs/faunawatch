/// Model representing a photo item in the gallery.
class GalleryItem {
  const GalleryItem({
    required this.id,
    this.title = '',
    this.location = '',
    this.date = '',
    this.category = 'All',
    this.imageAsset,
  });

  final String id;
  final String title;
  final String location;
  final String date;
  final String category;
  final String? imageAsset;

  GalleryItem copyWith({
    String? id,
    String? title,
    String? location,
    String? date,
    String? category,
    String? imageAsset,
  }) {
    return GalleryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      date: date ?? this.date,
      category: category ?? this.category,
      imageAsset: imageAsset ?? this.imageAsset,
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
        other.imageAsset == imageAsset;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, location, date, category, imageAsset);
}

/// State container for the Gallery screen.
class GalleryState {
  const GalleryState({
    this.items = const [],
    this.selectedCategory = 'All',
    this.isLoading = false,
  });

  final List<GalleryItem> items;
  final String selectedCategory;
  final bool isLoading;

  /// Returns items filtered by [selectedCategory].
  List<GalleryItem> get filteredItems {
    if (selectedCategory == 'All') return items;
    return items.where((item) => item.category == selectedCategory).toList();
  }

  GalleryState copyWith({
    List<GalleryItem>? items,
    String? selectedCategory,
    bool? isLoading,
  }) {
    return GalleryState(
      items: items ?? this.items,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GalleryState &&
        other.items == items &&
        other.selectedCategory == selectedCategory &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode => Object.hash(items, selectedCategory, isLoading);
}
