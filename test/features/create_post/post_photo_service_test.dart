import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:exif/exif.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/create_post/services/post_photo_service.dart';

/// Native encoders are mocked on the Windows test host. Actual WebP bytes from
/// a bundled image stand in for the encoder result; source pixels are inspected.
class _FakeWebpEncoder extends FlutterImageCompressPlatform {
  late Uint8List output;
  Uint8List? input;
  CompressFormat? requestedFormat;
  int? requestedQuality, width, height;
  bool? keptExif, correctedAngle;
  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async {
    input = image;
    requestedFormat = format;
    requestedQuality = quality;
    width = minWidth;
    height = minHeight;
    keptExif = keepExif;
    correctedAngle = autoCorrectionAngle;
    return output;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File source;
  late _FakeWebpEncoder encoder;
  late FlutterImageCompressPlatform previousEncoder;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('post-webp-test');
    previousEncoder = FlutterImageCompressPlatform.instance;
    encoder = _FakeWebpEncoder()
      ..output = await File('assets/icons/up-load.webp').readAsBytes();
    FlutterImageCompressPlatform.instance = encoder;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF123456), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(4, 4);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    source = await File(
      '${directory.path}/source.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
  tearDown(() async {
    FlutterImageCompressPlatform.instance = previousEncoder;
    await directory.delete(recursive: true);
  });

  test(
    'prepares WebP at quality 88 from metadata-free pixels and hashes final bytes',
    () async {
      final prepared = await const DevicePostPhotoService().prepare(
        source.path,
      );
      expect(encoder.requestedFormat, CompressFormat.webp);
      expect(encoder.requestedQuality, 88);
      expect(encoder.keptExif, isFalse);
      expect(encoder.correctedAngle, isFalse);
      expect(encoder.width, 4);
      expect(encoder.height, 4);
      expect(await readExifFromBytes(encoder.input!), isEmpty);
      final codec = await ui.instantiateImageCodec(encoder.input!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 4);
      frame.image.dispose();
      codec.dispose();
      expect(prepared.bytes, encoder.output);
      expect(String.fromCharCodes(prepared.bytes.sublist(8, 12)), 'WEBP');
      expect(prepared.fingerprint, sha256.convert(encoder.output).toString());
    },
  );

  test(
    'rejects an original larger than 5 MB before invoking the encoder',
    () async {
      final file = File('${directory.path}/oversized.jpg');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(DevicePostPhotoService.maxBytes + 1);
      await handle.close();
      await expectLater(
        const DevicePostPhotoService().prepare(file.path),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('5 MB'),
          ),
        ),
      );
      expect(encoder.input, isNull);
    },
  );

  test('rejects encoded WebP over 5 MB', () async {
    encoder.output = Uint8List(DevicePostPhotoService.maxBytes + 1);
    await expectLater(
      const DevicePostPhotoService().prepare(source.path),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('5 MB'),
        ),
      ),
    );
  });

  test('does not label empty or non-WebP encoder results as WebP', () async {
    for (final output in [Uint8List(0), await source.readAsBytes()]) {
      encoder.output = output;
      await expectLater(
        const DevicePostPhotoService().prepare(source.path),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('WebP'),
          ),
        ),
      );
    }
  });
}
