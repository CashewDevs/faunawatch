import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';

export 'package:faunawatch/features/gallery/models/gallery_item.dart';

/// Riverpod notifier managing gallery photo items and filtering state.
class GalleryViewModel extends Notifier<GalleryState> {
  late final GalleryService _galleryService;

  @override
  GalleryState build() {
    _galleryService = ref.watch(galleryServiceProvider);
    _loadItems();
    return const GalleryState(isLoading: true);
  }

  Future<void> _loadItems() async {
    try {
      final items = await _galleryService.fetchGalleryItems();
      state = state.copyWith(items: items, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sets the active category filter for the gallery photos.
  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }
}

/// Riverpod provider exposing [GalleryViewModel] and [GalleryState].
final galleryViewModelProvider =
    NotifierProvider<GalleryViewModel, GalleryState>(GalleryViewModel.new);
