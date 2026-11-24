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

    test('pruning drops species missing from the ticked categories', () {
      const filter = MapPinFilter(
        categories: {_invasive},
        species: {'cane toad', 'philippine cobra'},
      );
      expect(
        filter.prunedFor(_posts),
        const MapPinFilter(categories: {_invasive}, species: {'cane toad'}),
      );
      // Nothing to drop: the same filter comes back.
      const kept = MapPinFilter(species: {'cane toad'});
      expect(kept.prunedFor(_posts), same(kept));
      expect(kept.prunedFor(const []), const MapPinFilter());
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
  });
}
