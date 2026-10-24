import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_header.dart';

class ImmediateGalleryService implements GalleryService {
  @override
  Future<List<GalleryItem>> fetchGalleryItems() async {
    return const [
      GalleryItem(
        id: '1',
        title: 'Barn Owl',
        category: 'Birds',
        date: 'Oct 19',
      ),
      GalleryItem(
        id: '2',
        title: 'Red Fox',
        category: 'Mammals',
        date: 'Oct 19',
      ),
      GalleryItem(
        id: '3',
        title: 'Peregrine Falcon',
        category: 'Birds',
        date: 'Oct 19',
      ),
    ];
  }
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        galleryServiceProvider.overrideWithValue(ImmediateGalleryService()),
      ],
      child: const MaterialApp(home: GalleryView()),
    );
  }

  group('GalleryView', () {
    testWidgets(
      'renders background vertical gradient 0% #DCF2FF to 100% #A4DDFF',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate((w) {
            if (w is Container && w.decoration is BoxDecoration) {
              final grad = (w.decoration as BoxDecoration).gradient;
              if (grad is LinearGradient) {
                return grad.colors.contains(
                      AppColors.galleryBackgroundGradientStart,
                    ) &&
                    grad.colors.contains(
                      AppColors.galleryBackgroundGradientEnd,
                    ) &&
                    grad.begin == Alignment.topCenter &&
                    grad.end == Alignment.bottomCenter;
              }
            }
            return false;
          }),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders Gallery header with title, underline, and Filter button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GalleryHeader), findsOneWidget);
        expect(find.text('Gallery'), findsOneWidget);
        expect(find.text('Filter'), findsOneWidget);

        // Verify yellow underline is present
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    AppColors.galleryTitleUnderline,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders 3-column grid of GalleryCards with #FFF7D6 details footer',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GalleryCard), findsNWidgets(3));
        expect(find.text('Barn Owl'), findsOneWidget);
        expect(find.text('Red Fox'), findsOneWidget);
        expect(find.text('Peregrine Falcon'), findsOneWidget);

        // Verify #FFF7D6 details container exists in each card
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container && w.color == AppColors.galleryCardDetailsYellow,
          ),
          findsNWidgets(3),
        );
      },
    );

    testWidgets('tapping Filter button opens dropdown menu and filters items', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(GalleryCard), findsNWidgets(3));

      // Tap Filter dropdown button
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Birds'), findsOneWidget);
      expect(find.text('Mammals'), findsOneWidget);

      // Tap Birds dropdown item
      await tester.tap(find.text('Birds'));
      await tester.pumpAndSettle();

      // Only birds should remain (2 birds, 0 mammals)
      expect(find.byType(GalleryCard), findsNWidgets(2));
      expect(find.text('Barn Owl'), findsOneWidget);
      expect(find.text('Peregrine Falcon'), findsOneWidget);
      expect(find.text('Red Fox'), findsNothing);
    });
  });
}
