import 'dart:ui' as ui;

import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Renders the existing FaunaWatch logo as a report pin at 2x scale.
Future<StyleImage> createReportPinImage() async {
  final asset = await rootBundle.load(AppAssets.appLogo);
  final codec = await ui.instantiateImageCodec(
    asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
  );
  try {
    final logo = (await codec.getNextFrame()).image;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final blue = ui.Paint()..color = const ui.Color(0xFF2563EB);
      final pointer = ui.Path()
        ..moveTo(38, 85)
        ..lineTo(52, 128)
        ..lineTo(66, 85)
        ..close();
      canvas.drawPath(pointer, blue);
      canvas.drawCircle(const ui.Offset(52, 49), 46, blue);
      canvas.drawCircle(
        const ui.Offset(52, 49),
        43,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      canvas.drawImageRect(
        logo,
        ui.Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        ui.Rect.fromCenter(
          center: const ui.Offset(52, 49),
          width: 68,
          height: 68 * logo.height / logo.width,
        ),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(104, 128);
        try {
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          return StyleImage.rgba(
            width: 104,
            height: 128,
            pixels: bytes!.buffer.asUint8List(),
          );
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      logo.dispose();
    }
  } finally {
    codec.dispose();
  }
}
