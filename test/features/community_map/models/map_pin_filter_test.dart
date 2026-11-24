import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/models/map_pin_filter.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
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
  _post('toad-1', _invasive, 'Cane toad'),
  _post('cobra-2', _dangerous, 'philippine  Cobra'),
  _post('eagle', _inNeed, 'Philippine eagle'),
  _post('unknown', _inNeed),
  _post('cobra-3', _inNeed, 'Philippine cobra'),
];

List<String> _ids(List<CommunityReport> reports) =>
    reports.map((r) => r.id).toList();

void main() {
  group('CommunityReport species', () {
    Map<String, dynamic> row(Object? species) => {
      'id': 'r1',
      'category': 'animal_in_need',
      'latitude': 10,
      'longitude': 123,
      'possible_species': species,
    };

    test("reads the AI's top guess like the Feed", () {
      expect(
        CommunityReport.fromJson(
          row([
            {'common_name': ' Cane toad ', 'scientific_name': 'Rhinella'},
            {'common_name': 'Asian toad'},
          ]),
        ).species,
        'Cane toad',
      );
      expect(
        CommunityReport.fromJson(
          row([
            {'name': 'Monitor lizard'},
          ]),
        ).species,
        'Monitor lizard',
      );
    });

    test('has no species without a usable guess', () {
      for (final value in [
        null,
        <Object>[],
        ['text'],
        [
          {'common_name': '  '},
        ],
      ]) {
        final report = CommunityReport.fromJson(row(value));
        expect(report.species, isNull, reason: '$value');
        expect(report.speciesKey, MapPinFilter.unknownSpeciesKey);
      }
    });

    test('the key ignores capitals and extra spaces', () {
      expect(_posts[0].speciesKey, 'philippine cobra');
      expect(_posts[2].speciesKey, 'philippine cobra');
    });
  });

  group('MapPinFilter', () {
    test('an empty filter shows every post', () {
      const filter = MapPinFilter();
      expect(filter.isActive, isFalse);
      expect(filter.tickedCount, 0);
      expect(filter.apply(_posts), same(_posts));
    });

    test('ticked categories show posts in any of them', () {
      const filter = MapPinFilter(categories: {_dangerous, _invasive});
      expect(filter.isActive, isTrue);
      expect(_ids(filter.apply(_posts)), ['cobra-1', 'toad-1', 'cobra-2']);
    });

    test('ticked species narrow the ticked categories', () {
      const filter = MapPinFilter(
        categories: {_dangerous, _inNeed},
        species: {'philippine cobra', MapPinFilter.unknownSpeciesKey},
      );
      expect(filter.tickedCount, 4);
      expect(_ids(filter.apply(_posts)), [
        'cobra-1',
        'cobra-2',
        'unknown',
        'cobra-3',
      ]);
    });

    test('species alone work across every category', () {
      const filter = MapPinFilter(species: {'philippine cobra'});
      expect(_ids(filter.apply(_posts)), ['cobra-1', 'cobra-2', 'cobra-3']);
    });

    test('drops ticked species missing from the ticked categories', () {
      const filter = MapPinFilter(
        categories: {_invasive},
        species: {'cane toad', 'philippine cobra'},
      );
      expect(
        filter.withoutGoneSpecies(_posts),
        const MapPinFilter(categories: {_invasive}, species: {'cane toad'}),
      );
      // Nothing to drop: the same filter comes back.
      const kept = MapPinFilter(species: {'cane toad'});
      expect(kept.withoutGoneSpecies(_posts), same(kept));
      // Every ticked species gone: the ticks stay (see below).
      expect(kept.withoutGoneSpecies(const []), same(kept));
    });

    test('filters with the same ticks are equal', () {
      expect(
        const MapPinFilter(categories: {_inNeed, _dangerous}, species: {'a'}),
        const MapPinFilter(categories: {_dangerous, _inNeed}, species: {'a'}),
      );
      expect(
        const MapPinFilter(categories: {_inNeed, _dangerous}).hashCode,
        const MapPinFilter(categories: {_dangerous, _inNeed}).hashCode,
      );
      expect(
        const MapPinFilter(categories: {_inNeed}),
        isNot(const MapPinFilter(categories: {_dangerous})),
      );
    });

    test('counts posts per category, leaving out empty ones', () {
      expect(MapPinFilter.categoryCounts(_posts), {
        _dangerous: 2,
        _invasive: 1,
        _inNeed: 3,
      });
    });

    test('species options: most posts first, then by name, unknown last', () {
      expect(MapPinFilter.speciesOptions(_posts), const [
        MapSpeciesOption(
          key: 'philippine cobra',
          label: 'Philippine cobra',
          count: 3,
        ),
        MapSpeciesOption(key: 'cane toad', label: 'Cane toad', count: 1),
        MapSpeciesOption(
          key: 'philippine eagle',
          label: 'Philippine eagle',
          count: 1,
        ),
        MapSpeciesOption(
          key: MapPinFilter.unknownSpeciesKey,
          label: MapPinFilter.unknownSpeciesLabel,
          count: 1,
        ),
      ]);
    });

    test('species options only cover the ticked categories', () {
      expect(
        MapPinFilter.speciesOptions(_posts, categories: {_dangerous}),
        const [
          MapSpeciesOption(
            key: 'philippine cobra',
            label: 'Philippine cobra',
            count: 2,
          ),
        ],
      );
      expect(MapPinFilter.speciesOptions(const []), isEmpty);
    });

    test('a species shows the spelling most of its posts use', () {
      final options = MapPinFilter.speciesOptions([
        _post('a', _inNeed, 'cane TOAD'),
        _post('b', _inNeed, 'Cane toad'),
        _post('c', _inNeed, 'Cane toad'),
      ]);
      expect(options.single.label, 'Cane toad');
      expect(options.single.isUnknown, isFalse);
    });

    test('keeps the ticks when every ticked species is gone', () {
      const onlyDingo = MapPinFilter(species: {'dingo'});
      expect(onlyDingo.withoutGoneSpecies(_posts), same(onlyDingo));
      expect(onlyDingo.apply(_posts), isEmpty);

      // With another ticked species still there, the gone one is dropped.
      const dingoAndToad = MapPinFilter(species: {'dingo', 'cane toad'});
      expect(
        dingoAndToad.withoutGoneSpecies(_posts),
        const MapPinFilter(species: {'cane toad'}),
      );
      const noSpecies = MapPinFilter(categories: {_inNeed});
      expect(noSpecies.withoutGoneSpecies(_posts), same(noSpecies));
    });
  });

  group('MapFilterChoices', () {
    test('works out every number from the posts it was given', () {
      final posts = List.of(_posts);
      final choices = MapFilterChoices(posts);
      posts.add(_post('later', _inNeed, 'Cane toad'));

      expect(choices.categoryCounts, {_dangerous: 2, _invasive: 1, _inNeed: 3});
      expect(choices.speciesFor({_invasive}), const [
        MapSpeciesOption(key: 'cane toad', label: 'Cane toad', count: 1),
      ]);
      expect(choices.countMatching(const MapPinFilter()), 6);
      // Applied as the map would: the eagle tick is dropped because the
      // cobra tick is still there...
      expect(
        choices.countMatching(
          const MapPinFilter(
            categories: {_dangerous},
            species: {'philippine eagle', 'philippine cobra'},
          ),
        ),
        2,
      );
      // ...but kept when it is the only one, so nothing matches.
      expect(
        choices.countMatching(
          const MapPinFilter(
            categories: {_dangerous},
            species: {'philippine eagle'},
          ),
        ),
        0,
      );
    });

    test(
      'lists ticked species without posts with 0, so they can be unticked',
      () {
        final choices = MapFilterChoices(_posts);
        expect(
          choices.speciesFor(
            {_invasive},
            ticked: {
              'philippine eagle',
              'dingo',
              MapPinFilter.unknownSpeciesKey,
            },
          ),
          const [
            MapSpeciesOption(key: 'cane toad', label: 'Cane toad', count: 1),
            // No post anywhere: the stored name with a capital letter.
            MapSpeciesOption(key: 'dingo', label: 'Dingo', count: 0),
            // Spelled as its posts in other categories spell it.
            MapSpeciesOption(
              key: 'philippine eagle',
              label: 'Philippine eagle',
              count: 0,
            ),
            MapSpeciesOption(
              key: MapPinFilter.unknownSpeciesKey,
              label: MapPinFilter.unknownSpeciesLabel,
              count: 0,
            ),
          ],
        );
        // A ticked species that is listed anyway is not added twice.
        expect(
          choices.speciesFor({_invasive}, ticked: {'cane toad'}),
          hasLength(1),
        );
      },
    );
  });
}
