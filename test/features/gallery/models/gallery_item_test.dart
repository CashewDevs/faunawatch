import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';

void main() {
  group('GalleryItem', () {
    test('supports value equality and copyWith', () {
      const item1 = GalleryItem(
        id: '1',
        title: 'Eagle',
        location: 'Zone A',
        date: 'Oct 19',
        category: 'Animal in need',
        imageUrl: 'https://photos.invalid/eagle.webp',
      );

      final item2 = item1.copyWith(title: 'Golden Eagle');

      expect(item1 == item2, isFalse);
      expect(item2.title, 'Golden Eagle');
      expect(item2.category, 'Animal in need');
      expect(item2.imageUrl, item1.imageUrl);
      expect(
        item1.copyWith(imageUrl: 'https://photos.invalid/new.webp'),
        isNot(item1),
      );

      final item1Clone = item1.copyWith();
      expect(item1 == item1Clone, isTrue);
    });
  });

  group('GalleryState', () {
    const item1 = GalleryItem(
      id: '1',
      title: 'Hawk',
      category: 'Animal in need',
    );
    const item2 = GalleryItem(
      id: '2',
      title: 'Deer',
      category: 'Other wildlife incident',
    );

    test('filteredItems filters by selectedCategory', () {
      const stateAll = GalleryState(items: [item1, item2]);
      expect(stateAll.filteredItems.length, 2);

      final stateInNeed = stateAll.copyWith(selectedCategory: 'Animal in need');
      expect(stateInNeed.filteredItems.length, 1);
      expect(stateInNeed.filteredItems.first.title, 'Hawk');

      final stateOther = stateAll.copyWith(
        selectedCategory: 'Other wildlife incident',
      );
      expect(stateOther.filteredItems.length, 1);
      expect(stateOther.filteredItems.first.title, 'Deer');
    });
  });
}
