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
        category: 'Birds',
      );

      final item2 = item1.copyWith(title: 'Golden Eagle');

      expect(item1 == item2, isFalse);
      expect(item2.title, 'Golden Eagle');
      expect(item2.category, 'Birds');

      final item1Clone = item1.copyWith();
      expect(item1 == item1Clone, isTrue);
    });
  });

  group('GalleryState', () {
    const item1 = GalleryItem(id: '1', title: 'Hawk', category: 'Birds');
    const item2 = GalleryItem(id: '2', title: 'Deer', category: 'Mammals');

    test('filteredItems filters by selectedCategory', () {
      const stateAll = GalleryState(items: [item1, item2]);
      expect(stateAll.filteredItems.length, 2);

      final stateBirds = stateAll.copyWith(selectedCategory: 'Birds');
      expect(stateBirds.filteredItems.length, 1);
      expect(stateBirds.filteredItems.first.title, 'Hawk');

      final stateMammals = stateAll.copyWith(selectedCategory: 'Mammals');
      expect(stateMammals.filteredItems.length, 1);
      expect(stateMammals.filteredItems.first.title, 'Deer');
    });
  });
}
