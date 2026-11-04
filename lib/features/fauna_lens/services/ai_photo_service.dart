import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A photo ready to send to an AI provider.
class AiPhoto {
  const AiPhoto({required this.bytes, required this.mimeType});

  final Uint8List bytes;

  /// `image/jpeg` or `image/png`.
  final String mimeType;
}

/// Prepares a photo for sending to an AI provider.
abstract interface class AiPhotoService {
  /// The photo, shrunk for upload and re-encoded from its pixels so no EXIF
  /// (including GPS) is sent. Throws when the photo can't be read.
  Future<AiPhoto> prepare(String path);
}

class DeviceAiPhotoService implements AiPhotoService {
  const DeviceAiPhotoService();

  /// The shorter side is scaled down to at most this many pixels. Enough
  /// detail to identify an animal while keeping the request small.
  static const targetShortSide = 1024;
  static const jpegQuality = 80;

  @override
  Future<AiPhoto> prepare(String path) async {
    // XFile reads both device file paths and the blob URLs the image picker
    // returns on the web.
    final original = await XFile(path).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(original);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: targetSizeFor,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw const FormatException('Could not read this photo.');
        }
        final png = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        // The JPEG encoder is a native plugin that the web build doesn't load,
        // so the web sends the PNG. Both are encoded from pixels only.
        if (kIsWeb) return AiPhoto(bytes: png, mimeType: 'image/png');
        final jpeg = await FlutterImageCompress.compressWithList(
          png,
          minWidth: image.width,
          minHeight: image.height,
          quality: jpegQuality,
          format: CompressFormat.jpeg,
          keepExif: false,
          autoCorrectionAngle: false,
        );
        return AiPhoto(bytes: jpeg, mimeType: 'image/jpeg');
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Size to decode a [width] x [height] photo at: the shorter side becomes
  /// [targetShortSide], and smaller photos keep their size.
  @visibleForTesting
  static ui.TargetImageSize targetSizeFor(int width, int height) {
    final shortSide = width < height ? width : height;
    if (shortSide <= targetShortSide) return ui.TargetImageSize();
    final scale = targetShortSide / shortSide;
    return ui.TargetImageSize(
      width: (width * scale).round(),
      height: (height * scale).round(),
    );
  }
}

final aiPhotoServiceProvider = Provider<AiPhotoService>(
  (ref) => const DeviceAiPhotoService(),
);
