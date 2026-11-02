import 'dart:typed_data';

import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coordinatesFromExif', () {
    test('reads a north-east position', () async {
      final coordinates = await coordinatesFromExif(
        _jpegWithGps(
          latitude: const [14, 30, 0],
          latitudeRef: 'N',
          longitude: const [121, 0, 36],
          longitudeRef: 'E',
        ),
      );
      expect(coordinates!.latitude, closeTo(14.5, 0.0001));
      expect(coordinates.longitude, closeTo(121.01, 0.0001));
    });

    test('makes south and west negative', () async {
      final coordinates = await coordinatesFromExif(
        _jpegWithGps(
          latitude: const [33, 52, 0],
          latitudeRef: 'S',
          longitude: const [70, 40, 0],
          longitudeRef: 'W',
        ),
      );
      expect(coordinates!.latitude, lessThan(0));
      expect(coordinates.longitude, lessThan(0));
    });

    test('treats a position blanked to 0, 0 as none', () async {
      final coordinates = await coordinatesFromExif(
        _jpegWithGps(
          latitude: const [0, 0, 0],
          latitudeRef: 'N',
          longitude: const [0, 0, 0],
          longitudeRef: 'E',
        ),
      );
      expect(coordinates, isNull);
    });

    test('returns null for a file with no EXIF data', () async {
      expect(await coordinatesFromExif(const [1, 2, 3, 4]), isNull);
    });
  });
}

/// Builds the smallest JPEG the EXIF reader accepts: an APP1 segment holding a
/// little-endian TIFF with one IFD that points to a GPS IFD.
Uint8List _jpegWithGps({
  required List<int> latitude,
  required String latitudeRef,
  required List<int> longitude,
  required String longitudeRef,
}) {
  const gpsIfdOffset = 26;
  const entryCount = 4;
  const latitudeOffset = gpsIfdOffset + 2 + entryCount * 12 + 4;
  const longitudeOffset = latitudeOffset + 24;
  const tiffLength = longitudeOffset + 24;

  final tiff = ByteData(tiffLength);
  var at = 0;
  void u16(int value) {
    tiff.setUint16(at, value, Endian.little);
    at += 2;
  }

  void u32(int value) {
    tiff.setUint32(at, value, Endian.little);
    at += 4;
  }

  void entry(int tag, int type, int count, int value) {
    u16(tag);
    u16(type);
    u32(count);
    u32(value);
  }

  void ratios(List<int> values) {
    for (final value in values) {
      u32(value);
      u32(1);
    }
  }

  tiff.setUint8(0, 0x49);
  tiff.setUint8(1, 0x49);
  at = 2;
  u16(42);
  u32(8);

  u16(1);
  entry(0x8825, 4, 1, gpsIfdOffset); // GPSInfo pointer
  u32(0);

  u16(entryCount);
  entry(1, 2, 2, latitudeRef.codeUnitAt(0)); // GPSLatitudeRef
  entry(2, 5, 3, latitudeOffset); // GPSLatitude
  entry(3, 2, 2, longitudeRef.codeUnitAt(0)); // GPSLongitudeRef
  entry(4, 5, 3, longitudeOffset); // GPSLongitude
  u32(0);

  ratios(latitude);
  ratios(longitude);

  const exifHeader = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
  final segmentLength = 2 + exifHeader.length + tiffLength;
  return Uint8List.fromList([
    0xFF, 0xD8, // SOI
    0xFF, 0xE1, // APP1
    segmentLength >> 8,
    segmentLength & 0xFF,
    ...exifHeader,
    ...tiff.buffer.asUint8List(),
    0xFF, 0xD9, // EOI
  ]);
}
