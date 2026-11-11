import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/services/create_post_service.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/features/create_post/views/create_post_view.dart';
import 'package:faunawatch/features/create_post/services/location_search_service.dart';
import 'package:faunawatch/features/create_post/services/location_picker_map_service.dart';
import 'package:faunawatch/features/create_post/views/widgets/location_picker_canvas.dart';
import 'package:faunawatch/features/create_post/views/screens/location_picker_screen.dart';
import 'location_picker_fakes.dart';
import 'create_post_viewmodel_test.dart'
    show FakeCreatePostService, FakeLocations;
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import '../fauna_lens/ai_fakes.dart' show sampleIdentification;

void main() {
  testWidgets(
    'requires location, submits valid form, and displays review status',
    (tester) async {
      final service = FakeCreatePostService();
      final map = FakePickerMap();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => const Stream.empty()),
          createPostServiceProvider.overrideWithValue(service),
          photoLocationServiceProvider.overrideWithValue(FakeLocations()),
          locationSearchServiceProvider.overrideWithValue(FakePlaceSearch()),
          locationPickerMapServiceProvider.overrideWithValue(map),
          locationPickerCanvasBuilderProvider.overrideWithValue(
            FakePickerCanvas(map),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CreatePostView()),
        ),
      );
      FilledButton submitButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit post'),
      );
      expect(submitButton().onPressed, isNull);
      container
          .read(createPostViewModelProvider.notifier)
          .edit(category: ReportCategory.animalInNeed);
      await tester.pump();
      expect(submitButton().onPressed, isNull);
      expect(find.text('Latitude *'), findsNothing);
      expect(find.text('Longitude *'), findsNothing);
      await tester.ensureVisible(find.text('Choose observation location'));
      await tester.tap(find.text('Choose observation location'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerScreen), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use this location'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Cebu City');
      await tester.tap(find.byTooltip('Search places'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testPlace.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();
      expect(find.text(testPlace.label), findsOneWidget);
      expect(submitButton().onPressed, isNotNull);
      await tester.ensureVisible(find.text('Submit post'));
      await tester.tap(find.text('Submit post'));
      await tester.pumpAndSettle();
      expect(service.drafts.single.latitude, 10.3);
      expect(find.text('Post submitted'), findsOneWidget);
      expect(find.textContaining('pending review'), findsOneWidget);
      await tester.tap(find.text('Create another post'));
      await tester.pumpAndSettle();
      expect(submitButton().onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceling a pin change preserves the existing post location', (
    tester,
  ) async {
    final map = FakePickerMap();
    final container = ProviderContainer(
      overrides: [
        photoLocationServiceProvider.overrideWithValue(FakeLocations()),
        currentUserIdProvider.overrideWith((ref) => const Stream.empty()),
        locationSearchServiceProvider.overrideWithValue(FakePlaceSearch()),
        locationPickerMapServiceProvider.overrideWithValue(map),
        locationPickerCanvasBuilderProvider.overrideWithValue(
          FakePickerCanvas(map),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(createPostViewModelProvider.notifier).setLocation(testPlace);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreatePostView()),
      ),
    );
    await tester.ensureVisible(find.text(testPlace.label));
    await tester.tap(find.text(testPlace.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drop test pin'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      container.read(createPostViewModelProvider).locationLabel,
      testPlace.label,
    );
    expect(
      container.read(createPostViewModelProvider).location!.latitude,
      testPlace.latitude,
    );
    expect(tester.takeException(), isNull);
  });

  group('attached FaunaLens analysis', () {
    const photo = FaunaLensPhoto(
      path: 'bird.jpg',
      source: FaunaLensPhotoSource.camera,
    );

    Future<ProviderContainer> pumpForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => const Stream.empty()),
          createPostServiceProvider.overrideWithValue(FakeCreatePostService()),
          photoLocationServiceProvider.overrideWithValue(FakeLocations()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CreatePostView()),
        ),
      );
      return container;
    }

    testWidgets('is hidden without an analysis', (tester) async {
      final container = await pumpForm(tester);
      container.read(createPostViewModelProvider.notifier).usePhoto(photo);
      await tester.pump();
      expect(find.textContaining('FaunaLens AI analysis'), findsNothing);
      expect(find.text("Don't attach analysis"), findsNothing);
    });

    testWidgets('shows the top guess, severity and disclosure', (tester) async {
      final container = await pumpForm(tester);
      container
          .read(createPostViewModelProvider.notifier)
          .usePhoto(photo, aiResult: sampleIdentification());
      await tester.pump();
      expect(
        find.text('FaunaLens AI analysis will be saved with this post'),
        findsOneWidget,
      );
      expect(
        find.text('Red-eared Slider (Trachemys scripta elegans)'),
        findsOneWidget,
      );
      expect(find.text('Severity: Low'), findsOneWidget);
      expect(find.textContaining('Preliminary AI-assisted'), findsOneWidget);
      expect(find.textContaining('Possible invasive species:'), findsNothing);
    });

    testWidgets('shows the invasive hint when there is one', (tester) async {
      final container = await pumpForm(tester);
      container
          .read(createPostViewModelProvider.notifier)
          .usePhoto(photo, aiResult: sampleIdentification(invasive: true));
      await tester.pump();
      expect(
        find.text('Possible invasive species: Red-eared Slider'),
        findsOneWidget,
      );
    });

    testWidgets('says so when no animal was identified', (tester) async {
      final container = await pumpForm(tester);
      container
          .read(createPostViewModelProvider.notifier)
          .usePhoto(photo, aiResult: sampleIdentification(noAnimal: true));
      await tester.pump();
      expect(find.text('No animal identified'), findsOneWidget);
    });

    DropdownButtonFormField<ReportCategory> dropdown(WidgetTester tester) =>
        tester.widget(find.byType(DropdownButtonFormField<ReportCategory>));

    const helper =
        'Set by FaunaLens AI. Tap "Don\'t attach analysis" to choose it yourself.';

    testWidgets('locks the category to the AI result while attached', (
      tester,
    ) async {
      final container = await pumpForm(tester);
      container
          .read(createPostViewModelProvider.notifier)
          .usePhoto(
            photo,
            aiResult: sampleIdentification(
              category: ReportCategory.potentiallyDangerousAnimal,
            ),
          );
      await tester.pump();
      expect(dropdown(tester).onChanged, isNull);
      expect(find.text(helper), findsOneWidget);
      expect(
        find.text('Category: Potentially dangerous animal'),
        findsOneWidget,
      );
      expect(find.textContaining('No AI analysis attached.'), findsNothing);
    });

    testWidgets('the category is editable without an analysis', (tester) async {
      final container = await pumpForm(tester);
      container.read(createPostViewModelProvider.notifier).usePhoto(photo);
      await tester.pump();
      expect(dropdown(tester).onChanged, isNotNull);
      expect(find.text(helper), findsNothing);
      expect(find.textContaining('No AI analysis attached.'), findsOneWidget);
    });

    testWidgets('detaches without clearing the photo or form', (tester) async {
      final container = await pumpForm(tester);
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(
        photo,
        aiResult: sampleIdentification(category: ReportCategory.animalInNeed),
      );
      vm.edit(species: 'Turtle');
      await tester.pump();
      await tester.tap(find.text("Don't attach analysis"));
      await tester.pump();
      final state = container.read(createPostViewModelProvider);
      expect(state.aiResult, isNull);
      expect(state.photoPath, 'bird.jpg');
      expect(state.category, ReportCategory.animalInNeed);
      expect(state.species, 'Turtle');
      expect(find.textContaining('FaunaLens AI analysis'), findsNothing);
      expect(find.text('Remove photo'), findsOneWidget);
      expect(dropdown(tester).onChanged, isNotNull);
      expect(find.text(helper), findsNothing);
    });

    testWidgets('disappears with the photo', (tester) async {
      final container = await pumpForm(tester);
      container
          .read(createPostViewModelProvider.notifier)
          .usePhoto(photo, aiResult: sampleIdentification());
      await tester.pump();
      await tester.tap(find.text('Remove photo'));
      await tester.pump();
      expect(find.textContaining('FaunaLens AI analysis'), findsNothing);
    });

    testWidgets('detach button is disabled while busy', (tester) async {
      final container = await pumpForm(tester);
      final vm = container.read(createPostViewModelProvider.notifier);
      final service =
          container.read(createPostServiceProvider) as FakeCreatePostService;
      service.pending = Completer();
      vm.usePhoto(photo, aiResult: sampleIdentification());
      vm.edit(
        category: ReportCategory.animalInNeed,
        latitude: '10',
        longitude: '123',
      );
      final submission = vm.submit();
      await tester.pump();
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, "Don't attach analysis"),
      );
      expect(button.onPressed, isNull);
      service.pending!.complete('saved');
      await submission;
      await tester.pump();
    });
  });

  testWidgets('form fits a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const CreatePostView(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Submit post'));
    expect(tester.takeException(), isNull);
  });
}
