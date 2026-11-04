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
}
