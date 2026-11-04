import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:faunawatch/features/messages/models/chat_photo.dart';

abstract interface class ChatPhotoService {
  Future<ChatPhoto?> pickPhoto();
}

class DeviceChatPhotoService implements ChatPhotoService {
  DeviceChatPhotoService(this._picker);
  final ImagePicker _picker;
  @override
  Future<ChatPhoto?> pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return prepare(file);
  }

  /// Rebuild the image from decoded pixels; source metadata is never uploaded.
  Future<ChatPhoto> prepare(XFile file) async {
    if (await file.length() > ChatPhoto.maxBytes) {
      throw const FormatException('Choose a photo of 5 MB or less.');
    }
    final codec = await ui.instantiateImageCodec(
      await file.readAsBytes(),
      targetWidth: 1600,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png == null) {
          throw const FormatException('Could not read this photo.');
        }
        final bytes = await FlutterImageCompress.compressWithList(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          minWidth: frame.image.width,
          minHeight: frame.image.height,
          quality: 88,
          format: CompressFormat.webp,
          keepExif: false,
          autoCorrectionAngle: false,
        );
        if (bytes.length > ChatPhoto.maxBytes) {
          throw const FormatException(
            'The processed photo exceeds 5 MB. Choose a smaller photo.',
          );
        }
        if (bytes.length < 12 ||
            String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
            String.fromCharCodes(bytes.sublist(8, 12)) != 'WEBP') {
          throw const FormatException('Could not prepare this photo.');
        }
        return ChatPhoto(bytes);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}

final chatPhotoServiceProvider = Provider<ChatPhotoService>(
  (ref) => DeviceChatPhotoService(ImagePicker()),
);
