import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/boxed_photo.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_ai_result_screen.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_boxes_screen.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai_fakes.dart';

const _photo = FaunaLensPhoto(
  path: 'missing.jpg',
  source: FaunaLensPhotoSource.camera,
);

void main() {
  late FakeIdentificationService service;
  AiResultChoice? choice;
  var popped = false;

  setUp(() {
    service = FakeIdentificationService();
    choice = null;
    popped = false;
  });

  Future<void> open(
    WidgetTester tester, {
    FaunaLensPhoto photo = _photo,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
          speciesIdentificationServiceProvider.overrideWithValue(service),
          aiApiKeyStorageServiceProvider.overrideWithValue(FakeKeyStorage()),
          // "Add an AI key" opens Settings › AI Integration.
          aiBackupKeyStorageServiceProvider.overrideWithValue(
            FakeBackupKeyStorage(),
          ),
          aiPreferencesServiceProvider.overrideWithValue(
            FakePreferencesService(),
          ),
          windowSecurityServiceProvider.overrideWithValue(_NoWindowSecurity()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  choice = await Navigator.of(context).push<AiResultChoice>(
                    MaterialPageRoute(
                      builder: (_) => FaunaLensBoxesScreen(photo: photo),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  /// Drags across the photo from one fraction of it to another.
  Future<void> dragOnPhoto(WidgetTester tester, Offset from, Offset to) async {
    final rect = tester.getRect(find.byType(BoxedPhoto));
    Offset at(Offset fraction) =>
        rect.topLeft +
        Offset(rect.width * fraction.dx, rect.height * fraction.dy);
    final gesture = await tester.startGesture(at(from));
    await gesture.moveTo(at(Offset.lerp(from, to, 0.5)!));
    await gesture.moveTo(at(to));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('lists the animals found and analyses the chosen ones', (
    tester,
  ) async {
    service.found = [
      sampleBox(),
      sampleBox(
        color: AnimalBoxColor.blue,
        name: 'heron',
        left: 0.6,
        right: 0.9,
      ),
    ];
    await open(tester);

    expect(service.searchedPaths, ['missing.jpg']);
    expect(find.text('turtle'), findsOneWidget);
    expect(find.text('heron'), findsOneWidget);
    expect(find.bySemanticsLabel('heron, blue box'), findsOneWidget);

    await tester.tap(find.text('heron'));
    await tester.pump();
    await tester.tap(find.text('Analyse animal'));
    await tester.pumpAndSettle();

    expect(find.byType(FaunaLensAiResultScreen), findsOneWidget);
    expect(service.boxesAnalysed.single.single.name, 'heron');

    await tester.tap(find.text('Use these results'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(choice, isA<UseAiResults>());
  });

  testWidgets('tapping a box on the photo chooses it', (tester) async {
    service.found = [
      sampleBox(),
      sampleBox(
        color: AnimalBoxColor.blue,
        name: 'heron',
        left: 0.6,
        right: 0.9,
      ),
    ];
    await open(tester);

    final rect = tester.getRect(find.byType(BoxedPhoto));
    await tester.tapAt(
      rect.topLeft + Offset(rect.width * 0.75, rect.height * 0.4),
    );
    await tester.pump();

    expect(find.text('Analyse animal'), findsOneWidget);
    await tester.tap(find.text('Analyse animal'));
    await tester.pumpAndSettle();
    expect(service.boxesAnalysed.single.single.color, AnimalBoxColor.blue);
  });

  testWidgets('a fourth animal cannot be chosen', (tester) async {
    service.found = [
      for (final (i, name) in ['a', 'b', 'c', 'd'].indexed)
        sampleBox(
          color: AnimalBoxColor.values[i],
          name: name,
          left: i * 0.2,
          right: i * 0.2 + 0.15,
        ),
    ];
    await open(tester);

    for (final name in ['a', 'b', 'c', 'd']) {
      await tester.tap(find.text(name));
      await tester.pump();
    }

    expect(find.text('Analyse 3 animals'), findsOneWidget);
    expect(
      find.textContaining('You can choose up to 3 animals'),
      findsOneWidget,
    );
  });

  testWidgets('no animal found offers drawing a box or retaking', (
    tester,
  ) async {
    service.found = [];
    await open(tester);

    expect(find.textContaining('No animal was found.'), findsOneWidget);
    expect(find.text('Draw a box'), findsOneWidget);
    expect(find.text('Retake photo'), findsOneWidget);

    await tester.tap(find.text('Draw a box'));
    await tester.pump();
    expect(
      find.text('Drag across the animal to draw a box around it.'),
      findsOneWidget,
    );
    await dragOnPhoto(tester, const Offset(0.2, 0.2), const Offset(0.7, 0.8));

    expect(find.text('Your box'), findsOneWidget);
    await tester.tap(find.text('Analyse animal'));
    await tester.pumpAndSettle();
    final drawn = service.boxesAnalysed.single.single;
    expect(drawn.drawnByUser, isTrue);
    expect(drawn.left, closeTo(0.2, 0.01));
    expect(drawn.bottom, closeTo(0.8, 0.01));
  });

  testWidgets('a box drawn too small is refused with a message', (
    tester,
  ) async {
    service.found = [];
    await open(tester);

    await tester.tap(find.text('Draw a box'));
    await tester.pump();
    await dragOnPhoto(tester, const Offset(0.5, 0.5), const Offset(0.51, 0.51));

    expect(find.text('Your box'), findsNothing);
    expect(find.textContaining('That box was too small'), findsOneWidget);
  });

  testWidgets('Retake photo returns a retake choice', (tester) async {
    await open(tester);
    await tester.tap(find.text('Retake photo'));
    await tester.pumpAndSettle();
    expect(choice, isA<RetakeFromAiResult>());
  });

  testWidgets(
    'gallery mode gives Choose another photo more width than Draw a box',
    (tester) async {
      await open(
        tester,
        photo: const FaunaLensPhoto(
          path: 'missing.jpg',
          source: FaunaLensPhotoSource.gallery,
        ),
      );
      final drawWidth = tester
          .getSize(find.widgetWithText(PillButton, 'Draw a box'))
          .width;
      final chooseWidth = tester
          .getSize(find.widgetWithText(PillButton, 'Choose another photo'))
          .width;
      expect(chooseWidth, greaterThan(drawWidth));
      expect(chooseWidth / drawWidth, closeTo(5 / 3, 0.05));

      final analyseButton = tester.widget<PillButton>(
        find.widgetWithText(PillButton, 'Analyse animal'),
      );
      expect(analyseButton.primaryText, AppColors.faunaLensBlue);
    },
  );

  testWidgets('back from the AI Result keeps the boxes screen', (tester) async {
    await open(tester);
    await tester.tap(find.text('Analyse animal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(FaunaLensBoxesScreen), findsOneWidget);
    expect(popped, isFalse);
  });

  testWidgets('without a key, adding one searches again', (tester) async {
    service.findFailure = IdentificationFailure.noKey;
    await open(tester);

    expect(find.text('Add an AI key first'), findsOneWidget);
    await tester.tap(find.text('Add an AI key'));
    await tester.pumpAndSettle();
    expect(find.byType(AiIntegrationView), findsOneWidget);

    service.findFailure = null;
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();

    expect(service.searchedPaths, hasLength(2));
    expect(find.text('turtle'), findsOneWidget);
  });

  group('editing boxes', () {
    final deleteRed = find.byKey(const ValueKey('delete_box_red'));

    testWidgets('dragging a corner of the chosen box resizes it', (
      tester,
    ) async {
      service.found = [sampleBox()];
      await open(tester);
      expect(deleteRed, findsOneWidget);
      expect(find.textContaining('Drag a corner of the red box'), findsOne);

      // The red box runs from (0.1, 0.2) to (0.5, 0.6).
      await dragOnPhoto(tester, const Offset(0.5, 0.6), const Offset(0.7, 0.8));
      await tester.tap(find.text('Analyse animal'));
      await tester.pumpAndSettle();

      final box = service.boxesAnalysed.single.single;
      expect(box.name, 'turtle');
      expect(box.left, closeTo(0.1, 0.01));
      expect(box.top, closeTo(0.2, 0.01));
      expect(box.right, closeTo(0.7, 0.01));
      expect(box.bottom, closeTo(0.8, 0.01));
    });

    testWidgets('dragging inside the chosen box moves it', (tester) async {
      service.found = [sampleBox()];
      await open(tester);

      await dragOnPhoto(tester, const Offset(0.3, 0.4), const Offset(0.4, 0.5));
      await tester.tap(find.text('Analyse animal'));
      await tester.pumpAndSettle();

      final box = service.boxesAnalysed.single.single;
      expect(box.left, closeTo(0.2, 0.01));
      expect(box.top, closeTo(0.3, 0.01));
      expect(box.right, closeTo(0.6, 0.01));
      expect(box.bottom, closeTo(0.7, 0.01));
    });

    testWidgets('the delete button removes the box', (tester) async {
      service.found = [
        sampleBox(),
        sampleBox(
          color: AnimalBoxColor.blue,
          name: 'heron',
          left: 0.6,
          right: 0.9,
        ),
      ];
      await open(tester);
      // Nothing is being edited until a box is chosen.
      expect(deleteRed, findsNothing);

      await tester.tap(find.text('turtle'));
      await tester.pump();
      expect(find.bySemanticsLabel('Delete turtle, red box'), findsOneWidget);

      await tester.tap(deleteRed);
      await tester.pump();
      expect(find.text('turtle'), findsNothing);
      expect(find.text('heron'), findsOneWidget);
      expect(deleteRed, findsNothing);
      final analyse = tester.widget<PillButton>(
        find.widgetWithText(PillButton, 'Analyse animal'),
      );
      expect(analyse.onPressed, isNull);
    });

    testWidgets('boxes that are not chosen cannot be dragged', (tester) async {
      service.found = [
        sampleBox(),
        sampleBox(
          color: AnimalBoxColor.blue,
          name: 'heron',
          left: 0.6,
          right: 0.9,
        ),
      ];
      await open(tester);

      await dragOnPhoto(tester, const Offset(0.3, 0.4), const Offset(0.4, 0.5));
      await tester.tap(find.text('turtle'));
      await tester.pump();
      await tester.tap(find.text('Analyse animal'));
      await tester.pumpAndSettle();

      final box = service.boxesAnalysed.single.single;
      expect(box.left, closeTo(0.1, 1e-9));
      expect(box.top, closeTo(0.2, 1e-9));
    });
  });
}

class _NoWindowSecurity implements WindowSecurityService {
  @override
  Future<void> enableSecure() async {}

  @override
  Future<void> disableSecure() async {}
}
