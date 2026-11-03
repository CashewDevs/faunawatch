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
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';

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
