import 'dart:ui' as ui;

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Renders the shared blue location pin for Mapbox style images at 2x scale.
Future<StyleImage> createMapPinImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final path = ui.Path()
    ..moveTo(32, 84)
    ..cubicTo(25, 70, 4, 43, 4, 30)
    ..cubicTo(4, -6, 60, -6, 60, 30)
    ..cubicTo(60, 43, 39, 70, 32, 84)
    ..close();
  canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFF2563EB));
  canvas.drawCircle(
    const ui.Offset(32, 29),
    11,
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(64, 88);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return StyleImage.rgba(
        width: 64,
        height: 88,
        pixels: bytes!.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
