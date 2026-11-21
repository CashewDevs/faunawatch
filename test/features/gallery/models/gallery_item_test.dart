import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
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
    const approved = GalleryItem(id: '1', title: 'Hawk');
    const pending = GalleryItem(
      id: '2',
      title: 'Deer',
      status: ReportStatus.pending,
    );

    test('items know whether they are still pending', () {
      expect(pending.isPending, isTrue);
      expect(approved.isPending, isFalse);
      expect(pending.copyWith(title: 'Doe').status, ReportStatus.pending);
    });

    test('each filter has its own empty message', () {
      String title(GalleryFilter filter) =>
          GalleryState(filter: filter).emptyMessage.title;
      expect(title(const GalleryFilter()), 'No posts yet.');
      expect(
        const GalleryState().emptyMessage.hint,
        'Your approved and pending posts will appear here.',
      );
      expect(
        title(const GalleryFilter(status: GalleryStatusFilter.pending)),
        'Nothing waiting for review.',
      );
      expect(
        title(const GalleryFilter(status: GalleryStatusFilter.approved)),
        'No approved posts yet.',
      );
      expect(
        title(
          const GalleryFilter(
            status: GalleryStatusFilter.pending,
            category: ReportCategory.animalInNeed,
          ),
        ),
        'No posts in this category.',
      );
    });

    test('filters combine and the category can be cleared', () {
      const filter = GalleryFilter(category: ReportCategory.animalInNeed);
      final pendingInNeed = filter.copyWith(
        status: GalleryStatusFilter.pending,
      );
      expect(pendingInNeed.status, GalleryStatusFilter.pending);
      expect(pendingInNeed.category, ReportCategory.animalInNeed);
      expect(
        pendingInNeed.copyWith(clearCategory: true),
        const GalleryFilter(status: GalleryStatusFilter.pending),
      );
      expect(GalleryStatusFilter.all.statuses, [
        ReportStatus.approved,
        ReportStatus.pending,
      ]);
    });
  });
}
