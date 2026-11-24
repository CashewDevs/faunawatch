import 'dart:async';

import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_header.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_skeleton.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../feed/fake_feed_service.dart';
import '../fake_gallery_service.dart';

void main() {
  late FakeGalleryService service;

  setUp(() {
    service = FakeGalleryService(
      posts: [
        testPost(
          'own',
          authorId: 'me',
          title: 'Barn Owl',
          category: ReportCategory.animalInNeed,
        ),
        testPost(
          'other',
          title: 'Red Fox',
          category: ReportCategory.otherWildlifeIncident,
        ),
        testPost(
          'third',
          title: 'Peregrine Falcon',
          category: ReportCategory.animalInNeed,
        ),
      ],
    );
  });

  Future<void> pumpGallery(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [galleryServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: GalleryView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'keeps the background, Filter and three-column yellow-footer grid',
    (tester) async {
      await pumpGallery(tester);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
      expect(find.byType(GalleryHeader), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      for (final chip in ['All', 'Pending', 'Approved']) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(find.byType(GalleryCard), findsNWidgets(3));
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        3,
      );
      expect(find.text('Barn Owl'), findsOneWidget);
      expect(find.text('Red Fox'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container && w.color == AppColors.galleryCardDetailsYellow,
        ),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('filters by real report categories and restores All', (
    tester,
  ) async {
    await pumpGallery(tester);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    for (final category in ReportCategory.values) {
      expect(find.text(category.label), findsOneWidget);
    }
    await tester.tap(find.text(ReportCategory.animalInNeed.label));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsNWidgets(2));
    expect(find.text('Red Fox'), findsNothing);
    expect(service.filterRequests.last.category, ReportCategory.animalInNeed);
    final active = 'Filter · ${ReportCategory.animalInNeed.label}';
    expect(find.text(active), findsOneWidget);
    await tester.tap(find.text(active));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget);
    expect(find.byType(GalleryCard), findsNWidgets(3));
  });

  testWidgets('pending posts carry a badge under All and every filter', (
    tester,
  ) async {
    service.statuses['other'] = ReportStatus.pending;
    await pumpGallery(tester);
    expect(find.byType(GalleryCard), findsNWidgets(3));
    expect(find.byType(PostStatusBadge), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is GalleryCard && w.item.id == 'other',
        ),
        matching: find.byType(PostStatusBadge),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Red Fox.*Pending review')), findsOne);

    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsOneWidget);
    expect(find.text('Red Fox'), findsOneWidget);

    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsNWidgets(2));
    expect(find.byType(PostStatusBadge), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.byType(PostStatusBadge), findsOneWidget);
  });

  testWidgets('uses network photos and handles missing or failed photos', (
    tester,
  ) async {
    service.posts[0] = service.posts[0].copyWith(
      photoUrls: ['https://photos.invalid/report.webp'],
    );
    await pumpGallery(tester);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      'https://photos.invalid/report.webp',
    );
    expect(image.fit, BoxFit.cover);
    expect(find.byIcon(Icons.image_outlined), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty gallery can be pulled to refresh', (tester) async {
    service.posts = [];
    await pumpGallery(tester);
    expect(find.text('No posts yet.'), findsOneWidget);
    service.posts = [testPost('new', title: 'Fresh sighting')];
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Fresh sighting'), findsOneWidget);
  });

  testWidgets('initial error retries and refresh failure preserves cards', (
    tester,
  ) async {
    service.pageError = Exception('offline');
    await pumpGallery(tester);
    expect(find.text('Could not load your gallery.'), findsOneWidget);
    service.pageError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsNWidgets(3));
    service.pageError = Exception('offline');
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsNWidgets(3));
  });

  testWidgets('scrolling near the end loads older cards', (tester) async {
    service.posts = [
      for (var i = 0; i < 24; i++) testPost('p$i', index: i, title: 'Post $i'),
    ];
    await pumpGallery(tester);
    expect(service.pageRequests, hasLength(1));
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -600),
      1000,
    );
    await tester.pumpAndSettle();
    expect(service.pageRequests.length, greaterThan(1));
    expect(service.pageRequests[1]!.id, 'p11');
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching from All to Pending shows a skeleton, not a spinner', (
    tester,
  ) async {
    service.statuses['other'] = ReportStatus.pending;
    await pumpGallery(tester);
    expect(find.byType(GallerySkeleton), findsNothing);
    final gate = Completer<void>();
    service.pageGate = gate;
    await tester.tap(find.text('Pending'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GallerySkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(GalleryCard), findsNothing);
    expect(find.bySemanticsLabel('Loading your posts'), findsOneWidget);
    // The skeleton keeps the real grid's three columns.
    final grid = tester.widget<SliverGrid>(
      find.descendant(
        of: find.byType(GallerySkeleton),
        matching: find.byType(SliverGrid),
      ),
    );
    expect(grid.gridDelegate, galleryGridDelegate);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(GallerySkeleton), findsNothing);
    expect(find.byType(GalleryCard), findsOneWidget);
    expect(find.text('Red Fox'), findsOneWidget);
  });

  testWidgets('going back to a chip already opened shows its posts at once', (
    tester,
  ) async {
    service.statuses['other'] = ReportStatus.pending;
    await pumpGallery(tester);
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    service.pageGate = gate;
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.byType(GallerySkeleton), findsNothing);
    expect(find.byType(GalleryCard), findsNWidgets(3));
    await tester.tap(find.text('Pending'));
    await tester.pump();
    expect(find.byType(GallerySkeleton), findsNothing);
    expect(find.text('Red Fox'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsOneWidget);
  });

  testWidgets('the skeleton holds still when the device asks for less motion', (
    tester,
  ) async {
    final gate = Completer<void>();
    service.pageGate = gate;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [galleryServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: GalleryView(),
          ),
        ),
      ),
    );
    // Settles only because nothing is animating while the page loads.
    await tester.pumpAndSettle();
    expect(find.byType(GallerySkeleton), findsOneWidget);
    expect(
      tester
          .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
          .opacity
          .value,
      1,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsNWidgets(3));
  });

  testWidgets('each filter shows its own empty message', (tester) async {
    service.posts = [service.posts.first];
    await pumpGallery(tester);
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing waiting for review.'), findsOneWidget);
    expect(
      find.text('New posts stay here until an admin reviews them.'),
      findsOneWidget,
    );
    service.posts = [];
    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();
    expect(find.text('No approved posts yet.'), findsOneWidget);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReportCategory.otherWildlifeIncident.label));
    await tester.pumpAndSettle();
    expect(find.text('No posts in this category.'), findsOneWidget);
    expect(find.text('Load older posts'), findsNothing);
  });

  testWidgets('hidden posts carry a Hidden badge and have their own chip', (
    tester,
  ) async {
    service.hidden.add('other');
    await pumpGallery(tester);
    expect(find.byType(GalleryCard), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is GalleryCard && w.item.id == 'other',
        ),
        matching: find.byType(HiddenPostBadge),
      ),
      findsOneWidget,
    );
    expect(find.byType(HiddenPostBadge), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Red Fox.*Hidden')), findsOne);

    // The chip, not the badge that has the same word.
    await tester.tap(
      find.descendant(
        of: find.byType(GalleryHeader),
        matching: find.text('Hidden'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsOneWidget);
    expect(find.text('Red Fox'), findsOneWidget);

    service.hidden.clear();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('No hidden posts.'), findsOneWidget);
    expect(
      find.text('Posts you hide appear here. Only you can see them.'),
      findsOneWidget,
    );
  });
}
