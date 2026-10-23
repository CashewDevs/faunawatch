import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';

/// Contract for fetching gallery photo sightings.
abstract interface class GalleryService {
  Future<List<GalleryItem>> fetchGalleryItems();
}

/// Default implementation providing placeholder gallery photos.
///
/// Yields 12 placeholder photo items corresponding to the 4x3 grid mockup.
class FaunaGalleryService implements GalleryService {
  const FaunaGalleryService();

  @override
  Future<List<GalleryItem>> fetchGalleryItems() async {
    return List.generate(
      12,
      (index) => GalleryItem(
        id: 'gallery-$index',
        title: 'Observation #${index + 1}',
        location: 'Zone ${String.fromCharCode(65 + (index % 6))}',
        date: 'Oct 19',
        category: index.isEven ? 'Birds' : 'Mammals',
      ),
    );
  }
}

/// Riverpod provider exposing [GalleryService].
final galleryServiceProvider = Provider<GalleryService>((ref) {
  return const FaunaGalleryService();
});
