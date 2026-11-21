import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/services/create_post_service.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/create_post/views/create_post_view.dart';
import 'package:faunawatch/features/create_post/views/widgets/animated_check.dart';
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
  /// Opens Create Post as a page, the way FaunaLens does, and returns how
  /// the user left it (null until they do).
  Future<CreatePostExit? Function()> openAsPage(
    WidgetTester tester,
    ProviderContainer container, {
    ThemeData? theme,
  }) async {
    CreatePostExit? exit;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  exit = await Navigator.of(context).push<CreatePostExit>(
                    MaterialPageRoute(builder: (_) => const CreatePostView()),
                  );
                },
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    return () => exit;
  }

  ProviderContainer makeContainer({FakeCreatePostService? service}) {
    final map = FakePickerMap();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => const Stream.empty()),
        createPostServiceProvider.overrideWithValue(
          service ?? FakeCreatePostService(),
        ),
        photoLocationServiceProvider.overrideWithValue(FakeLocations()),
        locationSearchServiceProvider.overrideWithValue(FakePlaceSearch()),
        locationPickerMapServiceProvider.overrideWithValue(map),
        locationPickerCanvasBuilderProvider.overrideWithValue(
          FakePickerCanvas(map),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  const birdPhoto = FaunaLensPhoto(
    path: 'bird.jpg',
    source: FaunaLensPhotoSource.gallery,
  );

  testWidgets(
    'requires location, submits valid form, and shows the submitted check',
    (tester) async {
      final service = FakeCreatePostService();
      final container = makeContainer(service: service);
      final exit = await openAsPage(tester, container);
      FilledButton submitButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit post'),
      );
      expect(submitButton().onPressed, isNull);
      expect(find.text('Add a photo'), findsOneWidget);
      expect(find.text('A photo is required. 5 MB maximum.'), findsOneWidget);
      container.read(createPostViewModelProvider.notifier)
        ..usePhoto(birdPhoto)
        ..edit(category: ReportCategory.animalInNeed);
      await tester.pump();
      expect(submitButton().onPressed, isNull);
      expect(find.text('Tap to choose where you saw it'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Open full map'));
      await tester.tap(find.byTooltip('Open full map'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Cebu City');
      await tester.tap(find.byTooltip('Search places'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testPlace.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();
      expect(find.text(testPlace.label), findsOneWidget);
      expect(find.text('Tap to choose where you saw it'), findsNothing);
      expect(submitButton().onPressed, isNotNull);
      await tester.ensureVisible(find.text('Submit post'));
      await tester.tap(find.text('Submit post'));
      await tester.pumpAndSettle();
      expect(service.drafts.single.latitude, 10.3);
      expect(find.text('Post submitted for review'), findsOneWidget);
      expect(find.byType(AnimatedCheck), findsOneWidget);
      expect(find.textContaining('pending review'), findsOneWidget);
      expect(find.text('Create another post'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatePostView), findsNothing);
      expect(exit(), CreatePostExit.done);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back after submitting does the same as Done', (tester) async {
    final container = makeContainer();
    final exit = await openAsPage(tester, container);
    container.read(createPostViewModelProvider.notifier)
      ..usePhoto(birdPhoto)
      ..setLocation(testPlace)
      ..edit(category: ReportCategory.animalInNeed);
    await container.read(createPostViewModelProvider.notifier).submit();
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exit(), CreatePostExit.done);
  });

  testWidgets('plain back leaves without a choice and keeps the draft', (
    tester,
  ) async {
    final container = makeContainer();
    final exit = await openAsPage(tester, container);
    container.read(createPostViewModelProvider.notifier)
      ..usePhoto(birdPhoto)
      ..edit(description: 'Turtle on the road');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CreatePostView), findsNothing);
    expect(exit(), isNull);
    expect(
      container.read(createPostViewModelProvider).description,
      'Turtle on the road',
    );
  });

  testWidgets('Change photo goes back to the camera', (tester) async {
    final container = makeContainer();
    final exit = await openAsPage(tester, container);
    container.read(createPostViewModelProvider.notifier).usePhoto(birdPhoto);
    await tester.pump();

    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    expect(exit(), CreatePostExit.changePhoto);
  });

  testWidgets('removing the photo leaves a box that asks for one', (
    tester,
  ) async {
    final container = makeContainer();
    final exit = await openAsPage(tester, container);
    container.read(createPostViewModelProvider.notifier).usePhoto(birdPhoto);
    await tester.pump();

    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pump();
    expect(container.read(createPostViewModelProvider).photoPath, isNull);
    expect(find.text('Change photo'), findsNothing);

    await tester.tap(find.text('Add a photo'));
    await tester.pumpAndSettle();
    expect(exit(), CreatePostExit.changePhoto);
  });

  testWidgets('the title is on the left, and (i) shows the posting tips', (
    tester,
  ) async {
    await openAsPage(tester, makeContainer());

    final title = tester.getRect(find.text('Create post'));
    expect(title.center.dx, lessThan(400 / 2));
    expect(find.text('Share a wildlife observation'), findsNothing);

    await tester.tap(find.byTooltip('Posting tips'));
    await tester.pumpAndSettle();
    expect(find.text('Share a wildlife observation'), findsOneWidget);
    expect(find.textContaining('Stay at a safe distance'), findsOneWidget);
  });

  testWidgets('builds in dark mode, analysis and all', (tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = makeContainer();
    await openAsPage(tester, container, theme: AppTheme.darkTheme);
    container
        .read(createPostViewModelProvider.notifier)
        .usePhoto(birdPhoto, aiResult: sampleIdentification(invasive: true));
    await tester.pumpAndSettle();
    expect(
      find.text('FaunaLens AI analysis will be saved with this post'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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
    await tester.ensureVisible(find.byTooltip('Open full map'));
    await tester.tap(find.byTooltip('Open full map'));
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

    DropdownButton<ReportCategory> dropdown(WidgetTester tester) =>
        tester.widget(find.byType(DropdownButton<ReportCategory>));

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
      expect(find.byTooltip('Remove photo'), findsOneWidget);
      expect(dropdown(tester).onChanged, isNotNull);
      expect(find.text(helper), findsNothing);
    });

    testWidgets('disappears with the photo', (tester) async {
      final container = await pumpForm(tester);
      container
          .read(createPostViewModelProvider.notifier)
          .usePhoto(photo, aiResult: sampleIdentification());
      await tester.pump();
      await tester.tap(find.byTooltip('Remove photo'));
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
