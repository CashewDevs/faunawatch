import 'package:flutter/material.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/create_post/services/location_search_service.dart';
import 'package:faunawatch/features/create_post/services/location_picker_map_service.dart';
import 'package:faunawatch/features/create_post/views/widgets/location_picker_canvas.dart';
import 'package:faunawatch/features/create_post/views/screens/location_picker_screen.dart';
import 'package:faunawatch/features/create_post/viewmodels/location_picker_viewmodel.dart';
import 'package:faunawatch/features/create_post/models/post_location.dart';
import 'location_picker_fakes.dart';
import 'create_post_viewmodel_test.dart' show FakeLocations;
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';

void main() {
  testWidgets(
    'picker follows light and dark app themes without moving its pin',
    (tester) async {
      final mode = ValueNotifier(ThemeMode.dark);
      addTearDown(mode.dispose);
      final map = FakePickerMap();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationSearchServiceProvider.overrideWithValue(FakePlaceSearch()),
            photoLocationServiceProvider.overrideWithValue(FakeLocations()),
            locationPickerMapServiceProvider.overrideWithValue(map),
            locationPickerCanvasBuilderProvider.overrideWithValue(
              FakePickerCanvas(map),
            ),
          ],
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: mode,
            builder: (context, themeMode, child) => MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: themeMode,
              home: const LocationPickerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(map.appearanceCalls.last, isTrue);
      await tester.tap(find.text('Drop test pin'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LocationPickerScreen)),
      );
      mode.value = ThemeMode.light;
      await tester.pumpAndSettle();
      expect(map.appearanceCalls.last, isFalse);
      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(map.appearanceCalls.last, isTrue);
      expect(map.initialCameraLocations, [null]);
      expect(map.focuses, isEmpty);
      expect(
        container.read(locationPickerViewModelProvider(null)).selection,
        testPin,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GPS denial opens the regional map and still permits pinning', (
    tester,
  ) async {
    final map = FakePickerMap();
    final canvas = FakePickerCanvas(map);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationSearchServiceProvider.overrideWithValue(FakePlaceSearch()),
          photoLocationServiceProvider.overrideWithValue(FakeLocations()),
          locationPickerMapServiceProvider.overrideWithValue(map),
          locationPickerCanvasBuilderProvider.overrideWithValue(canvas),
        ],
        child: const MaterialApp(home: LocationPickerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      canvas.initialViewport!.center!.coordinates.lng,
      PostLocation.regionalFallback.longitude,
    );
    expect(
      canvas.initialViewport!.center!.coordinates.lat,
      PostLocation.regionalFallback.latitude,
    );
    expect(map.initialCameraLocations, [null]);
    expect(find.textContaining('Could not get your location'), findsOneWidget);
    await tester.tap(find.text('Drop test pin'));
    await tester.pumpAndSettle();
    expect(map.renders.last.location, testPin);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens in 3D and automatically centers on device GPS', (
    tester,
  ) async {
    final map = FakePickerMap();
    final canvas = FakePickerCanvas(map);
    final locations = FakeLocations()
      ..location = const GeoCoordinates(latitude: 14.6, longitude: 121);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationSearchServiceProvider.overrideWithValue(FakePlaceSearch()),
          photoLocationServiceProvider.overrideWithValue(locations),
          locationPickerMapServiceProvider.overrideWithValue(map),
          locationPickerCanvasBuilderProvider.overrideWithValue(canvas),
        ],
        child: const MaterialApp(home: LocationPickerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(canvas.initialViewport!.pitch, 55);
    expect(map.initialCameraLocations, [null]);
    expect(map.focuses.single.latitude, 14.6);
    expect(map.focuses.single.longitude, 121);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tap to pin enables confirmation; empty search gives map alternative',
    (tester) async {
      final map = FakePickerMap();
      final search = FakePlaceSearch()..results = [];
      final container = ProviderContainer(
        overrides: [
          locationSearchServiceProvider.overrideWithValue(search),
          photoLocationServiceProvider.overrideWithValue(FakeLocations()),
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
          child: const MaterialApp(home: LocationPickerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Unknown address');
      expect(search.calls, 0);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('No places found'), findsOneWidget);
      await tester.tap(find.text('Drop test pin'));
      await tester.pumpAndSettle();
      expect(
        container.read(locationPickerViewModelProvider(null)).selection,
        testPin,
      );
      expect(find.text('Pinned location'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picker fits narrow screens, large text, and an open keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final map = FakePickerMap();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationSearchServiceProvider.overrideWithValue(FakePlaceSearch()),
          photoLocationServiceProvider.overrideWithValue(FakeLocations()),
          locationPickerMapServiceProvider.overrideWithValue(map),
          locationPickerCanvasBuilderProvider.overrideWithValue(
            FakePickerCanvas(map),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const LocationPickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding(bottom: 280);
    await tester.enterText(find.byType(TextField), 'Cebu');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
