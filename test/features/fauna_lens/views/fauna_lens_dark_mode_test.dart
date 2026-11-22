import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_ai_result_screen.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_boxes_screen.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_review_screen.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai_fakes.dart';

const _photo = FaunaLensPhoto(
  path: 'missing.jpg',
  source: FaunaLensPhotoSource.gallery,
  locationStatus: FaunaLensLocationStatus.missing,
);

/// The screens after the camera follow the app's dark mode instead of
/// staying light.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required ThemeData theme,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final service = FakeIdentificationService()
      ..result = sampleIdentification(invasive: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
          speciesIdentificationServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(theme: theme, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color background(WidgetTester tester) =>
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor!;

  final screens = <String, Widget>{
    'Use this photo?': FaunaLensReviewScreen(
      photo: _photo,
      onBack: () {},
      onAskAi: () {},
      onChangePhoto: () {},
      onSkipAi: () {},
    ),
    'Choose animals': const FaunaLensBoxesScreen(photo: _photo),
    'AI Result': FaunaLensAiResultScreen(photo: _photo, boxes: [sampleBox()]),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name is dark in dark mode and light in light mode', (
      tester,
    ) async {
      await pump(tester, screen, theme: AppTheme.darkTheme);
      expect(tester.takeException(), isNull);
      expect(background(tester).computeLuminance(), lessThan(0.1));
      final dark = FaunaLensTheme.of(tester.element(find.byType(Scaffold)));
      expect(dark.isDark, isTrue);

      await pump(tester, screen, theme: AppTheme.lightTheme);
      expect(tester.takeException(), isNull);
      expect(background(tester).computeLuminance(), greaterThan(0.5));
    });
  }

  group('"Use this photo?" chip and notice (QA-030)', () {
    final pastels = {
      AppColors.faunaLensChipLocation,
      AppColors.faunaLensChipGallery,
      AppColors.faunaLensNotice,
    };

    Set<Color> fills(WidgetTester tester) => {
      for (final box in tester.widgetList<Container>(find.byType(Container)))
        if (box.decoration case BoxDecoration(:final Color color)) color,
    };

    double contrast(Color a, Color b) {
      final first = a.computeLuminance();
      final second = b.computeLuminance();
      return first > second
          ? (first + 0.05) / (second + 0.05)
          : (second + 0.05) / (first + 0.05);
    }

    Widget review(FaunaLensPhoto photo) => FaunaLensReviewScreen(
      photo: photo,
      onBack: () {},
      onAskAi: () {},
      onChangePhoto: () {},
      onSkipAi: () {},
    );

    const captured = FaunaLensPhoto(
      path: 'missing.jpg',
      source: FaunaLensPhotoSource.camera,
      locationStatus: FaunaLensLocationStatus.found,
    );

    testWidgets('use dark tints in dark mode, with readable text', (
      tester,
    ) async {
      for (final photo in [_photo, captured]) {
        await pump(tester, review(photo), theme: AppTheme.darkTheme);
        final colors = FaunaLensTheme.of(tester.element(find.byType(Scaffold)));
        expect(fills(tester).intersection(pastels), isEmpty);
        expect(
          fills(tester),
          contains(photo == _photo ? colors.chipGallery : colors.chipLocation),
        );
        for (final (text, fill) in [
          (colors.chipLocationText, colors.chipLocation),
          (colors.chipCheck, colors.chipLocation),
          (colors.chipGalleryText, colors.chipGallery),
          (colors.noticeText, colors.notice),
        ]) {
          expect(contrast(text, fill), greaterThanOrEqualTo(4.5));
        }
      }
      // The gallery photo has no location, so the notice shows too.
      await pump(tester, review(_photo), theme: AppTheme.darkTheme);
      expect(
        fills(tester),
        contains(
          FaunaLensTheme.of(tester.element(find.byType(Scaffold))).notice,
        ),
      );
    });

    testWidgets('keep the original pastels in light mode', (tester) async {
      await pump(tester, review(_photo), theme: AppTheme.lightTheme);
      expect(
        fills(tester),
        containsAll([
          AppColors.faunaLensChipGallery,
          AppColors.faunaLensNotice,
        ]),
      );
      await pump(tester, review(captured), theme: AppTheme.lightTheme);
      expect(fills(tester), contains(AppColors.faunaLensChipLocation));
    });

    testWidgets('use DM Sans, not Inter', (tester) async {
      await pump(tester, review(_photo), theme: AppTheme.lightTheme);
      final families = {
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          text.style?.fontFamily,
      }..remove(null);
      expect(families, isNotEmpty);
      for (final family in families) {
        expect(family, startsWith('DMSans'));
      }
    });
  });
}
