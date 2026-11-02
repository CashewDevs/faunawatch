import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Encapsulates the device camera used by FaunaLens.
abstract interface class FaunaLensCameraService {
  /// The open camera for the preview widget, or null while it is closed.
  CameraController? get controller;

  /// Opens the selected camera. Does nothing if it is already open.
  Future<void> start();

  /// Closes the camera and releases it for other apps.
  Future<void> stop();

  /// Opens the next camera. Returns false if the device only has one.
  Future<bool> switchLens();

  Future<void> setFlash({required bool isOn});

  /// Takes a photo and returns the path of the saved file.
  Future<String> takePicture();
}

/// [FaunaLensCameraService] implementation using the `camera` plugin.
class DeviceFaunaLensCameraService implements FaunaLensCameraService {
  List<CameraDescription> _cameras = const [];
  int _lensIndex = 0;
  CameraController? _controller;

  // App lifecycle changes can request a stop while a start is still running,
  // and the plugin does not allow those to overlap.
  Future<void> _queue = Future.value();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  @override
  CameraController? get controller => _controller;

  @override
  Future<void> start() => _enqueue(_open);

  @override
  Future<void> stop() => _enqueue(_close);

  @override
  Future<bool> switchLens() {
    return _enqueue(() async {
      if (_cameras.length < 2) return false;
      await _close();
      _lensIndex = (_lensIndex + 1) % _cameras.length;
      await _open();
      return true;
    });
  }

  @override
  Future<void> setFlash({required bool isOn}) {
    return _enqueue(() async {
      await _controller?.setFlashMode(isOn ? FlashMode.always : FlashMode.off);
    });
  }

  @override
  Future<String> takePicture() {
    return _enqueue(() async {
      final controller = _controller;
      if (controller == null) throw StateError('Camera is not open.');
      return (await controller.takePicture()).path;
    });
  }

  Future<void> _open() async {
    if (_controller != null) return;
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
      final back = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      _lensIndex = back == -1 ? 0 : back;
    }
    if (_cameras.isEmpty) throw StateError('No camera found on this device.');

    final controller = CameraController(
      _cameras[_lensIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    _controller = controller;
  }

  Future<void> _close() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

/// Riverpod provider exposing [FaunaLensCameraService].
final faunaLensCameraServiceProvider = Provider<FaunaLensCameraService>((ref) {
  return DeviceFaunaLensCameraService();
});
