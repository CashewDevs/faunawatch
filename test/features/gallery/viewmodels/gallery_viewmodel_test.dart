import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';

class MockGalleryService implements GalleryService {
  @override
  Future<List<GalleryItem>> fetchGalleryItems() async {
    return const [
      GalleryItem(id: '1', title: 'Owl', category: 'Birds'),
      GalleryItem(id: '2', title: 'Fox', category: 'Mammals'),
    ];
  }
}

void main() {
  group('GalleryViewModel', () {
    test('loads items on build', () async {
      final container = ProviderContainer(
        overrides: [
          galleryServiceProvider.overrideWithValue(MockGalleryService()),
        ],
      );
      addTearDown(container.dispose);

      container.read(galleryViewModelProvider);
      await pumpEventQueue();

      final state = container.read(galleryViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.items.length, 2);
    });

    test('updates selectedCategory', () {
      final container = ProviderContainer(
        overrides: [
          galleryServiceProvider.overrideWithValue(MockGalleryService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(galleryViewModelProvider.notifier);
      notifier.setCategory('Birds');

      expect(
        container.read(galleryViewModelProvider).selectedCategory,
        'Birds',
      );
    });
  });
}
