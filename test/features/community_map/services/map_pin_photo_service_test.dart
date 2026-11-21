import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:faunawatch/core/services/map_pin_image.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/services/map_pin_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A real encoded PNG of [width] x [height] in one colour.
Future<List<int>> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF00AA00),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  group('CommunityReport.photoPath', () {
    Map<String, dynamic> row(Object? photo) => {
      'id': 'r1',
      'category': 'animal_in_need',
      'latitude': 10.12,
      'longitude': 123.12,
      'description': 'Bird',
      'photo_path': photo,
    };

    test('reads the first photo path, or null', () {
      expect(
        CommunityReport.fromJson(row('r1/photo.webp')).photoPath,
        'r1/photo.webp',
      );
      expect(CommunityReport.fromJson(row(null)).photoPath, isNull);
      expect(CommunityReport.fromJson(row('  ')).photoPath, isNull);
      // Before the migration the column is missing.
      expect(
        CommunityReport.fromJson(row(null)..remove('photo_path')).photoPath,
        isNull,
      );
    });
  });

  test('a photo pin is the same size as the logo pin', () async {
    final pin = await createPhotoPinImage(
      Uint8List.fromList(await _png(900, 600)),
    );
    expect(pin, isA<StyleImageRgba>());
    final rgba = pin as StyleImageRgba;
    expect(rgba.width, 104);
    expect(rgba.height, 128);
    expect(rgba.pixels, hasLength(104 * 128 * 4));
  });

  group('SupabaseMapPinPhotoService', () {
    late List<http.Request> requests;
    late List<int>? photo;

    SupabaseClient client() => SupabaseClient(
      'https://pin-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final bytes = photo;
        if (bytes == null) {
          return http.Response('{"message":"not found"}', 404);
        }
        return http.Response.bytes(bytes, 200);
      }),
    );

    setUp(() => requests = []);

    test('downloads from report-images and draws the pin', () async {
      photo = await _png(40, 40);
      final supabase = client();
      addTearDown(supabase.dispose);
      final pin = await SupabaseMapPinPhotoService(
        supabase,
      ).loadPin('r1/photo.webp');
      expect(pin, isA<StyleImageRgba>());
      expect(requests.single.url.path, contains('report-images/r1/photo.webp'));
    });

    test('a missing or broken photo gives no pin', () async {
      final supabase = client();
      addTearDown(supabase.dispose);
      final service = SupabaseMapPinPhotoService(supabase);
      photo = null;
      expect(await service.loadPin('r1/gone.webp'), isNull);
      photo = [1, 2, 3];
      expect(await service.loadPin('r1/broken.webp'), isNull);
    });
  });
}
