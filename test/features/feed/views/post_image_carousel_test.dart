import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';

void main() {
  Future<void> showCarousel(WidgetTester tester, List<String> images) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: PostImageCarousel(imageAssets: images),
              ),
            ),
          ),
        ),
      );

  testWidgets(
    'swipes through photos, keeps full images, and stops at both ends',
    (tester) async {
      await showCarousel(tester, const [
        AppAssets.avatarGarfield,
        AppAssets.avatarPanda,
        AppAssets.avatarTweety,
      ]);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(image.fit, BoxFit.contain);
      }
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      for (final count in ['2 / 3', '3 / 3', '3 / 3']) {
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(find.text(count), findsOneWidget);
      }
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    },
  );

  testWidgets(
    'single and empty posts have no counter and media updates reset paging',
    (tester) async {
      await showCarousel(tester, const [
        AppAssets.avatarGarfield,
        AppAssets.avatarPanda,
      ]);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await showCarousel(tester, const [AppAssets.avatarTweety]);
      await tester.pumpAndSettle();
      expect(find.textContaining(' / '), findsNothing);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        const AssetImage(AppAssets.avatarTweety),
      );
      await showCarousel(tester, const []);
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
