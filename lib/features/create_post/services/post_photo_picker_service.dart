import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'post_photo_service.dart';

/// Picks the extra photos added on the post form, after the FaunaLens cover.
abstract interface class PostPhotoPickerService {
  /// A photo taken with the phone's camera, or null when cancelled.
  Future<String?> takePhoto();

  /// Up to [limit] photos from the phone's gallery; empty when cancelled.
  /// Some phones ignore the limit, so callers must still check the count.
  Future<List<String>> pickPhotos({required int limit});

  /// Whether the photo is over the 5 MB a post photo may be.
  Future<bool> isTooLarge(String path);
}

class DevicePostPhotoPickerService implements PostPhotoPickerService {
  DevicePostPhotoPickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // Larger than the 1600 px upload, so nothing is lost, while keeping
  // full-resolution camera files well under 5 MB.
  static const _maxSide = 2048.0;
  static const _quality = 90;

  @override
  Future<String?> takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
    );
    return file?.path;
  }

  @override
  Future<List<String>> pickPhotos({required int limit}) async {
    if (limit <= 0) return const [];
    // The several-photo picker refuses a limit below 2.
    if (limit == 1) {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      return [?file?.path];
    }
    final files = await _picker.pickMultiImage(
      limit: limit,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
    );
    return [for (final file in files) file.path];
  }

  @override
  Future<bool> isTooLarge(String path) async =>
      await XFile(path).length() > DevicePostPhotoService.maxBytes;
}

final postPhotoPickerServiceProvider = Provider<PostPhotoPickerService>(
  (ref) => DevicePostPhotoPickerService(),
);
