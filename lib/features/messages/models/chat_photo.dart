import 'dart:typed_data';

/// Re-encoded WebP pixels, with no EXIF or location metadata.
class ChatPhoto {
  const ChatPhoto(this.bytes);
  static const maxBytes = 5 * 1024 * 1024;
  final Uint8List bytes;
}
