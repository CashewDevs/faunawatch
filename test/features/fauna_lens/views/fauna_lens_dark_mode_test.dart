import 'package:faunawatch/core/auth/current_user_provider.dart';
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
}
