import 'dart:math' as math;

import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A FaunaLens photo with its animal boxes drawn over it, at the photo's own
/// shape so the boxes sit on the right spots.
///
/// Tapping a box calls [onTapBox]. While [isDrawing], dragging across the
/// photo draws a new box and calls [onBoxDrawn] with its corners as
/// fractions of the photo.
///
/// The [active] box (when given and not drawing) shows a handle on each
/// corner and a delete button. Dragging a handle resizes it and dragging
/// inside it moves it; each change is sent to [onBoxChanged]. The delete
/// button calls [onDeleteBox].
class BoxedPhoto extends StatefulWidget {
  const BoxedPhoto({
    super.key,
    required this.path,
    required this.boxes,
    this.chosen = const {},
    this.onTapBox,
    this.isDrawing = false,
    this.drawingColor,
    this.onBoxDrawn,
    this.active,
    this.onBoxChanged,
    this.onDeleteBox,
    this.showLabels = true,
    this.semanticLabel = 'Your photo',
  });

  final String path;
  final List<AnimalBox> boxes;
  final Set<AnimalBoxColor> chosen;
  final ValueChanged<AnimalBox>? onTapBox;
  final bool isDrawing;

  /// The colour the box being drawn will get.
  final AnimalBoxColor? drawingColor;
  final void Function(double x1, double y1, double x2, double y2)? onBoxDrawn;

  /// The colour of the box being edited.
  final AnimalBoxColor? active;
  final ValueChanged<AnimalBox>? onBoxChanged;
  final ValueChanged<AnimalBox>? onDeleteBox;

  /// Names on the boxes; off for small thumbnails.
  final bool showLabels;
  final String semanticLabel;

  @override
  State<BoxedPhoto> createState() => _BoxedPhotoState();
}

/// How far from a corner a finger may land and still grab its handle: half
/// the recommended 48 dp touch size.
const _handleReach = 24.0;

/// The delete button's touch size, and how far its centre sits from the box.
const _deleteTouchSize = 48.0;
const _deleteOffset = 34.0;

class _BoxedPhotoState extends State<BoxedPhoto> {
  /// Used until the photo's real shape is known.
  static const _defaultAspect = 3 / 4;

  ImageStream? _stream;
  late final _listener = ImageStreamListener(
    (info, _) {
      final aspect = info.image.width / info.image.height;
      info.dispose();
      if (mounted && aspect != _aspect) setState(() => _aspect = aspect);
    },
    onError: (_, _) {
      // The photo itself shows its error placeholder.
    },
  );
  double? _aspect;

  // The box being drawn, as fractions of the photo.
  Offset? _dragStart;
  Offset? _dragEnd;

  // The active box as it was when a resize or move began, the corner being
  // dragged (null while moving), and where the finger started.
  AnimalBox? _editStart;
  BoxCorner? _editCorner;
  Offset? _editFrom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(BoxedPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _aspect = null;
      _resolve();
    }
    if (!widget.isDrawing) _dragStart = _dragEnd = null;
    if (widget.active != oldWidget.active) _endEdit();
  }

  void _resolve() {
    final stream = localImageProvider(
      widget.path,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  /// The box that can be resized, moved and deleted right now.
  AnimalBox? get _editable {
    if (widget.isDrawing || widget.active == null) return null;
    for (final box in widget.boxes) {
      if (box.color == widget.active) return box;
    }
    return null;
  }

  Offset _fraction(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  static Rect _rectOf(AnimalBox box, Size size) => Rect.fromLTRB(
    box.left * size.width,
    box.top * size.height,
    box.right * size.width,
    box.bottom * size.height,
  );

  /// Starts resizing when the finger landed on a corner handle of the
  /// active box, or moving when it landed inside it.
  void _startEdit(Offset local, Size size) {
    final box = _editable;
    if (box == null || widget.onBoxChanged == null) return;
    BoxCorner? nearest;
    var nearestDistance = double.infinity;
    for (final corner in BoxCorner.values) {
      final at = box.cornerAt(corner);
      final distance =
          (Offset(at.x * size.width, at.y * size.height) - local).distance;
      if (distance <= _handleReach && distance < nearestDistance) {
        nearest = corner;
        nearestDistance = distance;
      }
    }
    if (nearest == null && !_rectOf(box, size).contains(local)) return;
    _editStart = box;
    _editCorner = nearest;
    _editFrom = Offset(local.dx / size.width, local.dy / size.height);
  }

  void _updateEdit(Offset local, Size size) {
    final start = _editStart;
    final from = _editFrom;
    if (start == null || from == null) return;
    final point = Offset(local.dx / size.width, local.dy / size.height);
    final corner = _editCorner;
    final cornerAt = corner == null ? null : start.cornerAt(corner);
    widget.onBoxChanged!(
      corner == null
          ? start.moved(point.dx - from.dx, point.dy - from.dy)
          // The corner keeps its distance from the finger, so it does not
          // jump to where the finger landed.
          : start.resized(
              corner,
              cornerAt!.x + point.dx - from.dx,
              cornerAt.y + point.dy - from.dy,
            ),
    );
  }

  void _endEdit() => _editStart = _editCorner = _editFrom = null;

  @override
  Widget build(BuildContext context) {
    final drawing = _dragStart != null && _dragEnd != null
        ? Rect.fromPoints(_dragStart!, _dragEnd!)
        : null;
    final editable = _editable;
    final canDrag =
        widget.isDrawing || (editable != null && widget.onBoxChanged != null);
    return AspectRatio(
      aspectRatio: _aspect ?? _defaultAspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Handles are found from where the finger first touched.
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: widget.onTapBox == null || widget.isDrawing
                ? null
                : (details) {
                    final point = _fraction(details.localPosition, size);
                    final box = AnimalBox.at(widget.boxes, point.dx, point.dy);
                    if (box != null) widget.onTapBox!(box);
                  },
            onPanStart: !canDrag
                ? null
                : (details) {
                    if (!widget.isDrawing) {
                      _startEdit(details.localPosition, size);
                      return;
                    }
                    setState(() {
                      _dragStart = _dragEnd = _fraction(
                        details.localPosition,
                        size,
                      );
                    });
                  },
            onPanUpdate: !canDrag
                ? null
                : (details) {
                    if (!widget.isDrawing) {
                      _updateEdit(details.localPosition, size);
                      return;
                    }
                    setState(() {
                      _dragEnd = _fraction(details.localPosition, size);
                    });
                  },
            onPanCancel: _endEdit,
            onPanEnd: !canDrag
                ? null
                : (_) {
                    if (!widget.isDrawing) {
                      _endEdit();
                      return;
                    }
                    final start = _dragStart;
                    final end = _dragEnd;
                    setState(() => _dragStart = _dragEnd = null);
                    if (start != null && end != null) {
                      widget.onBoxDrawn?.call(
                        start.dx,
                        start.dy,
                        end.dx,
                        end.dy,
                      );
                    }
                  },
            child: Stack(
              fit: StackFit.expand,
              children: [
                LocalImage(
                  widget.path,
                  fit: BoxFit.fill,
                  semanticLabel: widget.semanticLabel,
                  errorBuilder: (context, error, stackTrace) =>
                      ColoredBox(color: FaunaLensTheme.of(context).skeleton),
                ),
                CustomPaint(
                  painter: _BoxPainter(
                    boxes: widget.boxes,
                    chosen: widget.chosen,
                    active: editable?.color,
                    drawing: drawing,
                    drawingColor: widget.drawingColor,
                    showLabels: widget.showLabels,
                  ),
                ),
                if (editable != null && widget.onDeleteBox != null)
                  _deleteButton(editable, size),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The ✕ that deletes [box]: above its top-right corner, below its
  /// bottom-right corner when there is no room above, or just inside it when
  /// the box fills the photo's height. Always inside the photo.
  Widget _deleteButton(AnimalBox box, Size size) {
    const half = _deleteTouchSize / 2;
    final rect = _rectOf(box, size);
    var center = Offset(rect.right, rect.top - _deleteOffset);
    if (center.dy - half < 0) {
      center = Offset(rect.right, rect.bottom + _deleteOffset);
      if (center.dy + half > size.height) {
        center = Offset(rect.right - _deleteOffset, rect.top + _deleteOffset);
      }
    }
    center = Offset(
      center.dx.clamp(half, math.max(half, size.width - half)),
      center.dy.clamp(half, math.max(half, size.height - half)),
    );
    final color = Color(box.color.argb);
    final onColor = color.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    return Positioned(
      key: ValueKey('delete_box_${box.color.value}'),
      left: center.dx - half,
      top: center.dy - half,
      width: _deleteTouchSize,
      height: _deleteTouchSize,
      child: Semantics(
        button: true,
        label: 'Delete ${box.label}, ${box.color.value} box',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onDeleteBox!(box),
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4),
                ],
              ),
              child: Icon(Icons.close_rounded, size: 18, color: onColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({
    required this.boxes,
    required this.chosen,
    required this.active,
    required this.drawing,
    required this.drawingColor,
    required this.showLabels,
  });

  final List<AnimalBox> boxes;
  final Set<AnimalBoxColor> chosen;
  final AnimalBoxColor? active;
  final Rect? drawing;
  final AnimalBoxColor? drawingColor;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    Rect scaled(Rect fraction) => Rect.fromLTRB(
      fraction.left * size.width,
      fraction.top * size.height,
      fraction.right * size.width,
      fraction.bottom * size.height,
    );
    final thin = showLabels ? 2.0 : 1.5;
    final thick = showLabels ? 4.0 : 2.5;

    for (final box in boxes) {
      final color = Color(box.color.argb);
      final isChosen = chosen.contains(box.color);
      final rect = scaled(
        Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
      );
      if (isChosen) {
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.18));
      }
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isChosen ? thick : thin
          ..color = isChosen ? color : color.withValues(alpha: 0.75),
      );
      if (showLabels) _paintLabel(canvas, rect, box, color, isChosen);
    }

    // The box being edited gets a round handle on each corner, drawn last so
    // other boxes never cover them.
    for (final box in boxes) {
      if (box.color != active) continue;
      final rect = scaled(
        Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
      );
      final fill = Paint()..color = Colors.white;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color(box.color.argb);
      for (final corner in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        canvas.drawCircle(corner, 8, fill);
        canvas.drawCircle(corner, 8, ring);
      }
    }

    if (drawing != null) {
      canvas.drawRect(
        scaled(drawing!),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick
          ..color = drawingColor == null
              ? Colors.white
              : Color(drawingColor!.argb),
      );
    }
  }

  void _paintLabel(
    Canvas canvas,
    Rect rect,
    AnimalBox box,
    Color color,
    bool isChosen,
  ) {
    final text = TextPainter(
      text: TextSpan(
        text: isChosen ? '✓ ${box.label}' : box.label,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: rect.width < 40 ? 40 : rect.width);
    final tag = Rect.fromLTWH(
      rect.left,
      // Above the box when there is room, otherwise just inside it.
      rect.top >= text.height + 4 ? rect.top - text.height - 4 : rect.top,
      text.width + 8,
      text.height + 4,
    );
    canvas.drawRect(tag, Paint()..color = color);
    text.paint(canvas, tag.topLeft + const Offset(4, 2));
    text.dispose();
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.boxes != boxes ||
      old.chosen != chosen ||
      old.active != active ||
      old.drawing != drawing ||
      old.drawingColor != drawingColor ||
      old.showLabels != showLabels;
}
