import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/models/map_pin_filter.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_filter_sheet.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityReport _post(String id, ReportCategory category, [String? species]) =>
    CommunityReport(
      id: id,
      category: category.value,
      latitude: 10,
      longitude: 123,
      description: id,
      species: species,
    );

const _inNeed = ReportCategory.animalInNeed;
const _dangerous = ReportCategory.potentiallyDangerousAnimal;
const _invasive = ReportCategory.possibleInvasiveSpecies;

final _posts = [
  _post('cobra-1', _dangerous, 'Philippine cobra'),
  _post('cobra-2', _dangerous, 'Philippine cobra'),
  _post('toad', _invasive, 'Cane toad'),
  _post('eagle', _inNeed, 'Philippine eagle'),
  _post('unknown', _inNeed),
  _post('cobra-3', _inNeed, 'Philippine cobra'),
];

void main() {
  late MapPinFilter? result;
  late bool closed;

  Future<void> open(
    WidgetTester tester, {
    MapPinFilter initial = const MapPinFilter(),
    List<CommunityReport>? posts,
    double textScale = 1,
  }) async {
    result = null;
    closed = false;
    final reports = posts ?? _posts;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<MapPinFilter>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => MapFilterSheet(
                      initial: initial,
                      choices: MapFilterChoices(reports),
                    ),
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder tile(String label) => find.widgetWithText(CheckboxListTile, label);

  /// Scrolls the sheet's list until [finder] is built and on screen: rows
  /// below the fold are not built yet.
  Future<void> reveal(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        80,
        scrollable: find
            .descendant(
              of: find.byType(MapFilterSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  Future<void> tapTile(WidgetTester tester, String label) async {
    await reveal(tester, tile(label));
    await tester.tap(tile(label));
    await tester.pumpAndSettle();
  }

  TextButton clearButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Clear'));

  testWidgets(
    'lists categories and species with counts and applies the ticks',
    (tester) async {
      await open(tester);
      expect(find.text('Filter pins'), findsOneWidget);
      expect(
        find.descendant(of: tile('Animal in need'), matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile('Other wildlife incident'),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(tile('Cane toad'), findsOneWidget);
      await reveal(tester, tile(MapPinFilter.unknownSpeciesLabel));
      expect(tile(MapPinFilter.unknownSpeciesLabel), findsOneWidget);
      expect(find.text('Show all posts'), findsOneWidget);
      expect(clearButton(tester).onPressed, isNull);

      // Ticking a category narrows the species to the ones in it.
      await tapTile(tester, 'Potentially dangerous animal');
      expect(tile('Cane toad'), findsNothing);
      expect(
        find.descendant(of: tile('Philippine cobra'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.text('Show 2 posts'), findsOneWidget);

      await tapTile(tester, 'Philippine cobra');
      await tester.tap(find.text('Show 2 posts'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(
        result,
        const MapPinFilter(
          categories: {_dangerous},
          species: {'philippine cobra'},
        ),
      );
    },
  );

  testWidgets('starts from the current filter; Clear unticks everything', (
    tester,
  ) async {
    await open(tester, initial: const MapPinFilter(categories: {_inNeed}));
    final inNeed = tester.widget<CheckboxListTile>(tile('Animal in need'));
    expect(inNeed.value, isTrue);
    expect(find.text('Show 3 posts'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(tile('Animal in need')).value,
      isFalse,
    );
    expect(find.text('Show all posts'), findsOneWidget);
    expect(clearButton(tester).onPressed, isNull);
  });

  testWidgets('closing without Show keeps the old filter', (tester) async {
    await open(tester, initial: const MapPinFilter(categories: {_inNeed}));
    await tapTile(tester, 'Possible invasive species');
    // Tap above the sheet, on the dimmed map.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('Show is off when no post matches', (tester) async {
    await open(tester);
    await tapTile(tester, 'Other wildlife incident');
    expect(find.text('No posts match'), findsOneWidget);
    expect(find.text('No posts to pick a species from.'), findsOneWidget);
    final show = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(show.onPressed, isNull);
  });

  testWidgets('with no posts loaded, a filter can still be removed', (
    tester,
  ) async {
    await open(
      tester,
      posts: const [],
      initial: const MapPinFilter(categories: {_inNeed}),
    );
    expect(find.text('No posts match'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all posts'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, const MapPinFilter());
  });

  testWidgets('a long species list gets a search box', (tester) async {
    await open(
      tester,
      posts: [
        for (var i = 0; i < MapFilterSheet.searchFrom; i++)
          _post('bird-$i', _inNeed, 'Bird $i'),
        _post('toad', _invasive, 'Cane toad'),
      ],
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'TOAD');
    await tester.pumpAndSettle();
    expect(tile('Cane toad'), findsOneWidget);
    expect(tile('Bird 0'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.pumpAndSettle();
    expect(find.text('No species match "zebra".'), findsOneWidget);
  });

  testWidgets('a short species list has no search box', (tester) async {
    await open(tester);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('fits a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester, textScale: 1.8);
    await reveal(tester, tile(MapPinFilter.unknownSpeciesLabel));
    await tester.pumpAndSettle();
    expect(find.text('Show all posts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
