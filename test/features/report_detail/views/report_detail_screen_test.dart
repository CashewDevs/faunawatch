import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_result_cards.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';
import 'package:faunawatch/features/report_detail/views/screens/report_detail_screen.dart';

class _FakeReportDetailService implements ReportDetailService {
  _FakeReportDetailService(this.report);

  final OwnReport? report;

  @override
  Future<OwnReport?> fetchOwnReport(String reportId) async => report;

  @override
  Future<({double latitude, double longitude})?> fetchOwnLocation(
    String reportId,
  ) async => null;
}

void main() {
  OwnReport makeReport(ReportStatus status) => OwnReport(
    status: status,
    post: FeedPost(
      id: 'rep-1',
      authorId: 'user-a',
      authorName: 'Spotter',
      title: 'Domestic Dog (Canis lupus familiaris)',
      categoryLabel: 'Other wildlife incident',
      placeName: 'Guadalupe, Cebu City',
      description: 'Resting under a table.',
      photoUrls: const [
        'https://example.invalid/dog1.webp',
        'https://example.invalid/dog2.webp',
      ],
      createdAt: DateTime(2026, 11, 24),
      feedAt: DateTime(2026, 11, 24),
    ),
  );

  testWidgets(
    'pending report uses AI Result header, enlarged full-picture carousel, name below photo, and prominent notice card',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reportDetailServiceProvider.overrideWithValue(
              _FakeReportDetailService(makeReport(ReportStatus.pending)),
            ),
          ],
          child: const MaterialApp(home: ReportDetailScreen(reportId: 'rep-1')),
        ),
      );
      await tester.pumpAndSettle();

      // Header matches AI Result (FaunaLensPageHeader)
      expect(find.byType(FaunaLensPageHeader), findsOneWidget);
      expect(find.text('Your report'), findsOneWidget);
      final backIcon = tester.widget<Icon>(
        find.byIcon(Icons.chevron_left_rounded),
      );
      expect(backIcon.color, AppColors.aiResultBackChevron);

      // Enlarged full-picture swipeable carousel
      final carousel = tester.widget<PostImageCarousel>(
        find.byType(PostImageCarousel),
      );
      expect(carousel.fit, BoxFit.contain);
      final photoRect = tester.getRect(
        find.byKey(const ValueKey('report_detail_photo_container')),
      );
      expect(photoRect.height, greaterThanOrEqualTo(380));
      expect(find.text('1 / 2'), findsOneWidget);

      // Swipe to second photo
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      // Name directly below the photo, and prominent Pending review notice card below the name
      final nameRect = tester.getRect(
        find.text('Domestic Dog (Canis lupus familiaris)'),
      );
      final statusCardFinder = find.byKey(
        const ValueKey('report_detail_status_card'),
      );
      final statusRect = tester.getRect(statusCardFinder);

      expect(nameRect.top, greaterThanOrEqualTo(photoRect.bottom));
      expect(statusRect.top, greaterThan(nameRect.bottom));
      expect(statusRect.height, greaterThanOrEqualTo(80));
      expect(find.text('Pending review'), findsOneWidget);
      final pendingDescription = tester.widget<Text>(
        find.text('An admin has not reviewed this report yet.'),
      );
      expect(pendingDescription.maxLines, 1);
      expect(pendingDescription.softWrap, isFalse);

      final statusDecoration =
          tester.widget<Container>(statusCardFinder).decoration!
              as BoxDecoration;
      expect(statusDecoration.color, AppColors.galleryFilterButtonBackground);
      expect(
        (statusDecoration.border! as Border).top.color,
        AppColors.faunaLensBlue,
      );
    },
  );
}
