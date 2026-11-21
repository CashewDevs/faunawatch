import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:flutter/material.dart';

/// A FaunaLens photo with its animal boxes drawn over it, at the photo's own
/// shape so the boxes sit on the right spots.
///
/// Tapping a box calls [onTapBox]. While [isDrawing], dragging across the
/// photo draws a new box and calls [onBoxDrawn] with its corners as
/// fractions of the photo.
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

  /// Names on the boxes; off for small thumbnails.
  final bool showLabels;
  final String semanticLabel;

  @override
  State<BoxedPhoto> createState() => _BoxedPhotoState();
}

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

  Offset _fraction(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  @override
  Widget build(BuildContext context) {
    final drawing = _dragStart != null && _dragEnd != null
        ? Rect.fromPoints(_dragStart!, _dragEnd!)
        : null;
    return AspectRatio(
      aspectRatio: _aspect ?? _defaultAspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.onTapBox == null || widget.isDrawing
                ? null
                : (details) {
                    final point = _fraction(details.localPosition, size);
                    final box = AnimalBox.at(widget.boxes, point.dx, point.dy);
                    if (box != null) widget.onTapBox!(box);
                  },
            onPanStart: widget.isDrawing
                ? (details) => setState(() {
                    _dragStart = _dragEnd = _fraction(
                      details.localPosition,
                      size,
                    );
                  })
                : null,
            onPanUpdate: widget.isDrawing
                ? (details) => setState(() {
                    _dragEnd = _fraction(details.localPosition, size);
                  })
                : null,
            onPanEnd: widget.isDrawing
                ? (_) {
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
                  }
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LocalImage(
                  widget.path,
                  fit: BoxFit.fill,
                  semanticLabel: widget.semanticLabel,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: AppColors.aiResultSkeleton),
                ),
                CustomPaint(
                  painter: _BoxPainter(
                    boxes: widget.boxes,
                    chosen: widget.chosen,
                    drawing: drawing,
                    drawingColor: widget.drawingColor,
                    showLabels: widget.showLabels,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({
    required this.boxes,
    required this.chosen,
    required this.drawing,
    required this.drawingColor,
    required this.showLabels,
  });

  final List<AnimalBox> boxes;
  final Set<AnimalBoxColor> chosen;
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
      old.drawing != drawing ||
      old.drawingColor != drawingColor ||
      old.showLabels != showLabels;
}
