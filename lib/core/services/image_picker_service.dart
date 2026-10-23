import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Contract for selecting images from the device gallery or filesystem.
abstract interface class ImagePickerService {
  Future<String?> pickImage();
}

/// Device-backed implementation of [ImagePickerService] using [ImagePicker].
class DeviceImagePickerService implements ImagePickerService {
  DeviceImagePickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file?.path;
  }
}

/// Riverpod provider exposing [ImagePickerService].
final imagePickerServiceProvider = Provider<ImagePickerService>((ref) {
  return DeviceImagePickerService();
});
