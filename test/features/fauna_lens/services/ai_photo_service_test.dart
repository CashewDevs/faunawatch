import 'dart:ui';

import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/services/ai_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceAiPhotoService.targetSizeFor', () {
    test('shrinks a landscape photo so its height is the target', () {
      final size = DeviceAiPhotoService.targetSizeFor(4000, 3000);
      expect(size.width, 1365);
      expect(size.height, 1024);
    });

    test('shrinks a portrait photo so its width is the target', () {
      final size = DeviceAiPhotoService.targetSizeFor(3000, 4000);
      expect(size.width, 1024);
      expect(size.height, 1365);
    });

    test('keeps a small photo at its own size', () {
      final size = DeviceAiPhotoService.targetSizeFor(800, 600);
      expect(size.width, isNull);
      expect(size.height, isNull);
    });
  });

  group('boxes drawn for the AI', () {
    test('sit on the same spot of the shrunk photo', () {
      const box = AnimalBox(
        left: 0.25,
        top: 0.1,
        right: 0.75,
        bottom: 0.5,
        color: AnimalBoxColor.red,
      );
      expect(
        DeviceAiPhotoService.boxRect(box, 1365, 1024),
        const Rect.fromLTRB(341.25, 102.4, 1023.75, 512),
      );
    });

    test('lines grow with the photo but stay at least 3 pixels', () {
      expect(
        DeviceAiPhotoService.boxStrokeWidth(1365, 1024),
        closeTo(8.19, 0.01),
      );
      expect(DeviceAiPhotoService.boxStrokeWidth(200, 100), 3);
    });
  });
}
