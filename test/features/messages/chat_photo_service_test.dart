import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:exif/exif.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:faunawatch/features/messages/models/chat_photo.dart';
import 'package:faunawatch/features/messages/services/chat_photo_service.dart';

class _Encoder extends FlutterImageCompressPlatform {
  late Uint8List output;
  Uint8List? input;
  bool? keptExif;
  CompressFormat? format;
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
    keptExif = keepExif;
    this.format = format;
    return output;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late XFile source;
  late _Encoder encoder;
  late FlutterImageCompressPlatform previous;
  final service = DeviceChatPhotoService(ImagePicker());
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('chat-photo-test');
    previous = FlutterImageCompressPlatform.instance;
    encoder = _Encoder()
      ..output = await File('assets/icons/up-load.webp').readAsBytes();
    FlutterImageCompressPlatform.instance = encoder;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF123456), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(4, 4);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = await File(
      '${directory.path}/photo.png',
    ).writeAsBytes(png!.buffer.asUint8List());
    source = XFile(file.path);
    image.dispose();
    picture.dispose();
  });
  tearDown(() async {
    FlutterImageCompressPlatform.instance = previous;
    await directory.delete(recursive: true);
  });
  test('re-encodes only pixels as WebP without EXIF or GPS', () async {
    final photo = await service.prepare(source);
    expect(encoder.format, CompressFormat.webp);
    expect(encoder.keptExif, isFalse);
    expect(await readExifFromBytes(encoder.input!), isEmpty);
    expect(photo.bytes, encoder.output);
    expect(String.fromCharCodes(photo.bytes.sublist(8, 12)), 'WEBP');
  });
  test('rejects oversized source before decoding or encoding', () async {
    final file = File('${directory.path}/large.jpg');
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(ChatPhoto.maxBytes + 1);
    await handle.close();
    await expectLater(service.prepare(XFile(file.path)), throwsFormatException);
    expect(encoder.input, isNull);
  });
  test('rejects oversized output and invalid encoder results', () async {
    for (final output in [
      Uint8List(ChatPhoto.maxBytes + 1),
      Uint8List(0),
      await source.readAsBytes(),
    ]) {
      encoder.output = output;
      await expectLater(service.prepare(source), throwsFormatException);
    }
  });
}
