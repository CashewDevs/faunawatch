import 'dart:ui' as ui;

import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Pin size in pixels; drawn at 2x, so it shows as 52 x 64 on the map.
const _pinWidth = 104, _pinHeight = 128;
const _center = ui.Offset(52, 49);
const _pinBlue = ui.Color(0xFF2563EB);

/// Renders the shared FaunaWatch logo pin with a blue background at 2x scale.
Future<StyleImage> createMapPinImage() async {
  final asset = await rootBundle.load(AppAssets.appLogo);
  final logo = await _decode(
    asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
  );
  try {
    return await _renderPin((canvas) {
      canvas.drawImageRect(
        logo,
        ui.Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        ui.Rect.fromCenter(
          center: _center,
          width: 68,
          height: 68 * logo.height / logo.width,
        ),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    });
  } finally {
    logo.dispose();
  }
}

/// Renders the same blue pin with [photoBytes] (any format Flutter can decode)
/// cropped into its round head. The photo is decoded small, so a large upload
/// costs little memory.
Future<StyleImage> createPhotoPinImage(Uint8List photoBytes) async {
  final photo = await _decode(photoBytes, targetSize: 160);
  try {
    return await _renderPin((canvas) {
      const radius = 41.0;
      final side = photo.width < photo.height ? photo.width : photo.height;
      // Centre crop to a square, then fill the circle.
      final source = ui.Rect.fromCenter(
        center: ui.Offset(photo.width / 2, photo.height / 2),
        width: side.toDouble(),
        height: side.toDouble(),
      );
      canvas
        ..save()
        ..clipPath(
          ui.Path()
            ..addOval(ui.Rect.fromCircle(center: _center, radius: radius)),
        )
        ..drawImageRect(
          photo,
          source,
          ui.Rect.fromCircle(center: _center, radius: radius),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        )
        ..restore();
    });
  } finally {
    photo.dispose();
  }
}

/// Decodes [bytes]; with [targetSize], the shorter side is scaled to about
/// that many pixels while decoding.
Future<ui.Image> _decode(Uint8List bytes, {int? targetSize}) async {
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    int? width, height;
    if (targetSize != null) {
      final scale =
          targetSize /
          (descriptor.width < descriptor.height
              ? descriptor.width
              : descriptor.height);
      if (scale < 1) {
        width = (descriptor.width * scale).round();
        height = (descriptor.height * scale).round();
      }
    }
    codec = await descriptor.instantiateCodec(
      targetWidth: width,
      targetHeight: height,
    );
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// Draws the blue pin (round head and pointer) with [drawHead] on top.
Future<StyleImage> _renderPin(void Function(ui.Canvas canvas) drawHead) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final blue = ui.Paint()..color = _pinBlue;
  final pointer = ui.Path()
    ..moveTo(38, 85)
    ..lineTo(52, 128)
    ..lineTo(66, 85)
    ..close();
  canvas
    ..drawPath(pointer, blue)
    ..drawCircle(_center, 46, blue);
  drawHead(canvas);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(_pinWidth, _pinHeight);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return StyleImage.rgba(
        width: _pinWidth,
        height: _pinHeight,
        pixels: bytes!.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
