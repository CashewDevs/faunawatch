import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('listFromModelReply', () {
    test('turns 0-1000 [ymin, xmin, ymax, xmax] into photo fractions', () {
      final boxes = AnimalBox.listFromModelReply(
        '```json\n{"animals": [{"name": "brown dog", '
        '"box_2d": [100, 200, 600, 900]}]}\n```',
      );

      final box = boxes.single;
      expect(box.left, closeTo(0.2, 1e-9));
      expect(box.top, closeTo(0.1, 1e-9));
      expect(box.right, closeTo(0.9, 1e-9));
      expect(box.bottom, closeTo(0.6, 1e-9));
      expect(box.name, 'brown dog');
      expect(box.color, AnimalBoxColor.red);
      expect(box.drawnByUser, isFalse);
    });

    test('gives every box its own colour, in order', () {
      final boxes = AnimalBox.listFromModelReply(
        '{"animals": ['
        '{"name": "a", "box_2d": [0, 0, 100, 100]}, '
        '{"name": "b", "box_2d": [0, 500, 100, 600]}, '
        '{"name": "c", "box_2d": [500, 0, 600, 100]}]}',
      );
      expect(boxes.map((b) => b.color), [
        AnimalBoxColor.red,
        AnimalBoxColor.blue,
        AnimalBoxColor.yellow,
      ]);
    });

    test(
      'skips malformed, tiny and repeated boxes, and keeps edges inside',
      () {
        final boxes = AnimalBox.listFromModelReply(
          '{"animals": ['
          '{"name": "no box"}, '
          '{"name": "three edges", "box_2d": [1, 2, 3]}, '
          '{"name": "text", "box_2d": ["a", 0, 100, 100]}, '
          '{"name": "sliver", "box_2d": [100, 100, 105, 600]}, '
          '{"name": "swapped", "box_2d": [600, 900, 100, 200]}, '
          '{"name": "again", "box_2d": [102, 201, 601, 899]}, '
          '{"name": "outside", "box_2d": [-50, 800, 400, 1200]}, '
          '"not an object"]}',
        );
        expect(boxes.map((b) => b.name), ['swapped', 'outside']);
        expect(boxes.first.left, closeTo(0.2, 1e-9));
        expect(boxes.last.top, 0);
        expect(boxes.last.right, 1);
        // Colours follow the kept boxes, with no gaps.
        expect(boxes.last.color, AnimalBoxColor.blue);
      },
    );

    test('keeps at most one box per colour', () {
      final animals = [
        for (var i = 0; i < 9; i++)
          '{"name": "n$i", "box_2d": [${i * 100}, 0, ${i * 100 + 90}, 90]}',
      ].join(', ');
      final boxes = AnimalBox.listFromModelReply('{"animals": [$animals]}');
      expect(boxes, hasLength(AnimalBox.maxBoxes));
      expect(boxes.map((b) => b.color).toSet(), hasLength(AnimalBox.maxBoxes));
    });

    test('no animals, or no list, is an empty list', () {
      expect(AnimalBox.listFromModelReply('{"animals": []}'), isEmpty);
      expect(AnimalBox.listFromModelReply('{"other": 1}'), isEmpty);
    });

    test('a reply without JSON is a format error', () {
      expect(
        () => AnimalBox.listFromModelReply('I see a dog.'),
        throwsFormatException,
      );
    });

    test('long names are shortened', () {
      final box = AnimalBox.listFromModelReply(
        '{"animals": [{"name": "${'very ' * 20}long", '
        '"box_2d": [0, 0, 500, 500]}]}',
      ).single;
      expect(box.name.length, lessThanOrEqualTo(AnimalBox.maxNameLength + 1));
      expect(box.name, endsWith('…'));
    });
  });

  test('fromCorners accepts corners in any order and rejects small boxes', () {
    final box = AnimalBox.fromCorners(
      x1: 0.8,
      y1: 0.9,
      x2: 0.2,
      y2: 0.1,
      color: AnimalBoxColor.green,
      drawnByUser: true,
    )!;
    expect([box.left, box.top, box.right, box.bottom], [0.2, 0.1, 0.8, 0.9]);
    expect(box.label, 'Your box');

    expect(
      AnimalBox.fromCorners(
        x1: 0.5,
        y1: 0.5,
        x2: 0.51,
        y2: 0.9,
        color: AnimalBoxColor.green,
      ),
      isNull,
    );
  });

  test('a tap picks the smallest box under it', () {
    const outer = AnimalBox(
      left: 0,
      top: 0,
      right: 1,
      bottom: 1,
      color: AnimalBoxColor.red,
    );
    const inner = AnimalBox(
      left: 0.4,
      top: 0.4,
      right: 0.6,
      bottom: 0.6,
      color: AnimalBoxColor.blue,
    );
    expect(AnimalBox.at([outer, inner], 0.5, 0.5), inner);
    expect(AnimalBox.at([outer, inner], 0.1, 0.1), outer);
    expect(AnimalBox.at([inner], 0.1, 0.1), isNull);
  });

  test('nextColor hands out the first unused colour', () {
    const blue = AnimalBox(
      left: 0,
      top: 0,
      right: 1,
      bottom: 1,
      color: AnimalBoxColor.blue,
    );
    expect(AnimalBox.nextColor(const []), AnimalBoxColor.red);
    expect(
      AnimalBox.nextColor([
        blue,
        const AnimalBox(
          left: 0,
          top: 0,
          right: 1,
          bottom: 1,
          color: AnimalBoxColor.red,
        ),
      ]),
      AnimalBoxColor.yellow,
    );
    final full = [
      for (final color in AnimalBoxColor.values)
        AnimalBox(left: 0, top: 0, right: 1, bottom: 1, color: color),
    ];
    expect(AnimalBox.nextColor(full), isNull);
  });

  test('describes its position in whole percentages', () {
    const box = AnimalBox(
      left: 0.104,
      top: 0.2,
      right: 0.456,
      bottom: 0.8,
      color: AnimalBoxColor.red,
    );
    expect(
      box.positionDescription,
      'from 10% to 46% across and 20% to 80% down the photo',
    );
  });

  test('colour names are read from replies', () {
    expect(AnimalBoxColor.parse(' Blue '), AnimalBoxColor.blue);
    expect(AnimalBoxColor.parse('teal'), isNull);
    expect(AnimalBoxColor.parse(null), isNull);
  });
}
