import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:exif/exif.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';

class PreparedPostPhoto {
  const PreparedPostPhoto({
    required this.bytes,
    required this.fingerprint,
    required this.exif,
  });
  final Uint8List bytes;
  final String fingerprint;
  final Map<String, dynamic> exif;
}

abstract interface class PostPhotoService {
  Future<PreparedPostPhoto> prepare(String path);
}

/// Decoding and re-encoding pixels prevents GPS/EXIF leaking through storage.
class DevicePostPhotoService implements PostPhotoService {
  const DevicePostPhotoService();
  static const maxBytes = 5 * 1024 * 1024;
  static const webpQuality = 88;

  @override
  Future<PreparedPostPhoto> prepare(String path) async {
    final file = XFile(path);
    if (await file.length() > maxBytes) {
      throw const FormatException('Choose a photo of 5 MB or less.');
    }
    final original = await file.readAsBytes();
    final tags = await readExifFromBytes(original);
    final gps = await coordinatesFromExif(original);
    final metadata = <String, dynamic>{
      if (gps != null) 'gps_latitude': gps.latitude,
      if (gps != null) 'gps_longitude': gps.longitude,
      if (tags['Image Make'] != null)
        'device_make': tags['Image Make']!.printable,
      if (tags['Image Model'] != null)
        'device_model': tags['Image Model']!.printable,
    };
    final codec = await ui.instantiateImageCodec(
      original,
      targetWidth: 1600,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw const FormatException(
            'Could not prepare this photo. Choose another photo.',
          );
        }
        // Pass only decoded pixels to the native encoder, never source EXIF/GPS.
        // The intermediate PNG stays in memory and is not uploaded.
        final pixels = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final bytes = await FlutterImageCompress.compressWithList(
          pixels,
          minWidth: frame.image.width,
          minHeight: frame.image.height,
          quality: webpQuality,
          format: CompressFormat.webp,
          keepExif: false,
          autoCorrectionAngle: false,
        );
        if (bytes.length > maxBytes) {
          throw const FormatException(
            'The processed photo exceeds 5 MB. Choose a smaller photo.',
          );
        }
        if (bytes.length < 12 ||
            String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
            String.fromCharCodes(bytes.sublist(8, 12)) != 'WEBP') {
          throw const FormatException(
            'Could not convert this photo to WebP. Choose another photo.',
          );
        }
        return PreparedPostPhoto(
          bytes: bytes,
          fingerprint: sha256.convert(bytes).toString(),
          exif: metadata,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}

final postPhotoServiceProvider = Provider<PostPhotoService>(
  (ref) => const DevicePostPhotoService(),
);
