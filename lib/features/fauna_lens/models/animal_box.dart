import 'dart:math' as math;

import 'package:faunawatch/features/fauna_lens/models/model_reply.dart';

/// The colours boxes are drawn in, handed out in this order so every box on a
/// photo has its own. Each has a plain name, so the AI can be told about "the
/// red box".
enum AnimalBoxColor {
  red('red', 0xFFE53935),
  blue('blue', 0xFF1E88E5),
  yellow('yellow', 0xFFFDD835),
  green('green', 0xFF43A047),
  purple('purple', 0xFF8E24AA),
  orange('orange', 0xFFFB8C00);

  const AnimalBoxColor(this.value, this.argb);

  /// The colour's name, as used in the AI instructions and replies.
  final String value;

  /// The colour as 0xAARRGGBB.
  final int argb;

  /// Reads a colour name from an AI reply, or null when it names none.
  static AnimalBoxColor? parse(Object? raw) {
    final text = raw?.toString().trim().toLowerCase();
    for (final color in values) {
      if (color.value == text) return color;
    }
    return null;
  }
}

/// A box around one animal on a FaunaLens photo, found by the AI or drawn by
/// the user. Edges are fractions of the photo's width and height, from 0 at
/// the top-left to 1 at the bottom-right, so they fit the photo at any size.
///
/// Boxes are only used to point the AI at animals; they are never saved.
class AnimalBox {
  const AnimalBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.color,
    this.name = '',
    this.drawnByUser = false,
  });

  /// The most boxes on one photo: one per colour.
  static int get maxBoxes => AnimalBoxColor.values.length;

  /// The most animals one analysis covers. The database keeps at most three
  /// species guesses per analysis, and each chosen animal gets one.
  static const maxChosen = 3;

  /// The smallest width or height a box may have, so a stray tap or a sliver
  /// is not taken for a box.
  static const minSize = 0.03;

  final double left;
  final double top;
  final double right;
  final double bottom;
  final AnimalBoxColor color;

  /// A few words on the animal, such as "brown dog". May be empty.
  final String name;
  final bool drawnByUser;

  double get width => right - left;
  double get height => bottom - top;
  double get area => width * height;

  /// What the box is called on screen.
  String get label => name.isNotEmpty
      ? name
      : drawnByUser
      ? 'Your box'
      : 'Animal';

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  /// Where the box is, in words the AI can follow, e.g. "from 10% to 40%
  /// across and 20% to 70% down the photo".
  String get positionDescription {
    String percent(double value) => '${(value * 100).round()}%';
    return 'from ${percent(left)} to ${percent(right)} across and '
        '${percent(top)} to ${percent(bottom)} down the photo';
  }

  /// A box between two corners in any order, kept inside the photo. Null when
  /// it is narrower or shorter than [minSize].
  static AnimalBox? fromCorners({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required AnimalBoxColor color,
    String name = '',
    bool drawnByUser = false,
  }) {
    double clamp(double value) => value.clamp(0.0, 1.0);
    final box = AnimalBox(
      left: clamp(math.min(x1, x2)),
      top: clamp(math.min(y1, y2)),
      right: clamp(math.max(x1, x2)),
      bottom: clamp(math.max(y1, y2)),
      color: color,
      name: name,
      drawnByUser: drawnByUser,
    );
    return box.width < minSize || box.height < minSize ? null : box;
  }

  /// The box at a tapped point. When boxes overlap, the smallest one wins, so
  /// an animal inside a bigger box can still be picked.
  static AnimalBox? at(List<AnimalBox> boxes, double x, double y) {
    AnimalBox? hit;
    for (final box in boxes) {
      if (box.contains(x, y) && (hit == null || box.area < hit.area)) {
        hit = box;
      }
    }
    return hit;
  }

  /// The first colour no box in [boxes] uses, or null when all are taken.
  static AnimalBoxColor? nextColor(List<AnimalBox> boxes) {
    final used = {for (final box in boxes) box.color};
    for (final color in AnimalBoxColor.values) {
      if (!used.contains(color)) return color;
    }
    return null;
  }

  /// How much two boxes cover the same area, from 0 (apart) to 1 (the same).
  double overlapWith(AnimalBox other) {
    final w = math.min(right, other.right) - math.max(left, other.left);
    final h = math.min(bottom, other.bottom) - math.max(top, other.top);
    if (w <= 0 || h <= 0) return 0;
    final shared = w * h;
    return shared / (area + other.area - shared);
  }

  @override
  bool operator ==(Object other) =>
      other is AnimalBox &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.color == color &&
      other.name == name &&
      other.drawnByUser == drawnByUser;

  @override
  int get hashCode =>
      Object.hash(left, top, right, bottom, color, name, drawnByUser);

  /// The longest name kept from the AI reply.
  static const maxNameLength = 30;

  /// Reads the box-finding reply: `{"animals": [{"name": "", "box_2d":
  /// [ymin, xmin, ymax, xmax]}]}`, with whole numbers from 0 to 1000.
  ///
  /// Boxes that are malformed, too small or nearly the same as an earlier one
  /// are skipped, and at most [maxBoxes] are kept, coloured in order. Throws
  /// [FormatException] when the reply holds no JSON object.
  static List<AnimalBox> listFromModelReply(String reply) {
    final json = decodeModelReplyObject(reply);
    final raw = json['animals'];
    if (raw is! List) return const [];

    final boxes = <AnimalBox>[];
    for (final entry in raw) {
      if (boxes.length == maxBoxes) break;
      if (entry is! Map) continue;
      final edges = entry['box_2d'];
      if (edges is! List || edges.length != 4 || edges.any((e) => e is! num)) {
        continue;
      }
      final [ymin, xmin, ymax, xmax] = [
        for (final edge in edges) (edge as num).toDouble() / 1000,
      ];
      final box = fromCorners(
        x1: xmin,
        y1: ymin,
        x2: xmax,
        y2: ymax,
        color: AnimalBoxColor.values[boxes.length],
        name: _name(entry['name']),
      );
      if (box == null) continue;
      if (boxes.any((earlier) => earlier.overlapWith(box) > 0.8)) continue;
      boxes.add(box);
    }
    return boxes;
  }

  static String _name(Object? raw) {
    if (raw is! String) return '';
    final name = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.length > maxNameLength
        ? '${name.substring(0, maxNameLength).trimRight()}…'
        : name;
  }
}
