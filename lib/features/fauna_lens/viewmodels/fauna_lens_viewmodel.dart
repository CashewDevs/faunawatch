import 'package:camera/camera.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/fauna_lens_camera_service.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the camera, the selected photo, and its location for FaunaLens.
class FaunaLensViewModel extends AutoDisposeNotifier<FaunaLensState> {
  late FaunaLensCameraService _camera;
  bool _isDisposed = false;

  // Identifies the latest camera request, so a slower earlier one cannot
  // overwrite the status after the camera was stopped or restarted.
  int _cameraRequest = 0;

  @override
  FaunaLensState build() {
    _camera = ref.watch(faunaLensCameraServiceProvider);
    ref.onDispose(() {
      _isDisposed = true;
      _cameraRequest++;
      _camera.stop();
    });
    return const FaunaLensState();
  }

  /// The open camera for the preview, or null while it is not ready.
  CameraController? get previewController =>
      state.cameraStatus == FaunaLensCameraStatus.ready
      ? _camera.controller
      : null;

  Future<void> startCamera() async {
    final request = ++_cameraRequest;
    state = state.copyWith(cameraStatus: FaunaLensCameraStatus.starting);
    try {
      await _camera.start();
      await _restoreFlash();
      if (request != _cameraRequest) return;
      state = state.copyWith(cameraStatus: FaunaLensCameraStatus.ready);
    } catch (e) {
      debugPrint('FaunaLensViewModel: Failed to start camera: $e');
      if (request != _cameraRequest) return;
      state = state.copyWith(cameraStatus: FaunaLensCameraStatus.unavailable);
    }
  }

  /// Releases the camera while the app is in the background.
  ///
  /// A start still in progress is left alone: the permission prompt it shows
  /// also backgrounds the app, and restarting would ask the user again.
  Future<void> pauseCamera() async {
    if (state.cameraStatus != FaunaLensCameraStatus.ready) return;
    await _stopCamera();
  }

  /// Reopens the camera if [pauseCamera] closed it.
  Future<void> resumeCamera() async {
    if (state.cameraStatus != FaunaLensCameraStatus.stopped ||
        state.photo != null) {
      return;
    }
    await startCamera();
  }

  /// Turns the flash on or off. Returns false if this camera has no flash.
  Future<bool> toggleFlash() async {
    final isOn = !state.isFlashOn;
    try {
      await _camera.setFlash(isOn: isOn);
      if (!_isDisposed) state = state.copyWith(isFlashOn: isOn);
      return true;
    } catch (e) {
      debugPrint('FaunaLensViewModel: Failed to set flash: $e');
      return false;
    }
  }

  /// Switches camera. Returns false if there is no other camera to switch to.
  Future<bool> switchLens() async {
    if (state.isBusy || state.cameraStatus != FaunaLensCameraStatus.ready) {
      return true;
    }
    final request = ++_cameraRequest;
    state = state.copyWith(
      isBusy: true,
      cameraStatus: FaunaLensCameraStatus.starting,
    );
    var hasOtherCamera = true;
    var status = FaunaLensCameraStatus.ready;
    try {
      hasOtherCamera = await _camera.switchLens();
      await _restoreFlash();
    } catch (e) {
      debugPrint('FaunaLensViewModel: Failed to switch camera: $e');
      status = FaunaLensCameraStatus.unavailable;
    }
    if (_isDisposed) return hasOtherCamera;
    state = state.copyWith(
      isBusy: false,
      cameraStatus: request == _cameraRequest ? status : null,
    );
    return hasOtherCamera;
  }

  /// Takes a photo and opens its review. Returns false if the capture failed.
  Future<bool> capture() async {
    if (state.isBusy || state.cameraStatus != FaunaLensCameraStatus.ready) {
      return true;
    }
    state = state.copyWith(isBusy: true);
    final String path;
    try {
      path = await _camera.takePicture();
    } catch (e) {
      debugPrint('FaunaLensViewModel: Failed to take photo: $e');
      if (!_isDisposed) state = state.copyWith(isBusy: false);
      return false;
    }
    if (_isDisposed) return true;

    final locations = ref.read(photoLocationServiceProvider);
    await _showPhoto(
      FaunaLensPhoto(path: path, source: FaunaLensPhotoSource.camera),
      locations.currentLocation,
    );
    return true;
  }

  /// Opens the device gallery. Cancelling keeps whatever is currently shown.
  Future<void> pickFromGallery() async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true);
    String? path;
    try {
      path = await ref.read(imagePickerServiceProvider).pickImage();
    } catch (e) {
      debugPrint('FaunaLensViewModel: Failed to pick photo: $e');
    }
    if (_isDisposed) return;
    if (path == null) {
      state = state.copyWith(isBusy: false);
      return;
    }

    final selectedPath = path;
    final locations = ref.read(photoLocationServiceProvider);
    await _showPhoto(
      FaunaLensPhoto(path: selectedPath, source: FaunaLensPhotoSource.gallery),
      () => locations.locationInPhoto(selectedPath),
    );
  }

  /// Drops the photo under review and returns to the live camera.
  Future<void> discardPhoto() async {
    state = state.copyWith(clearPhoto: true);
    await startCamera();
  }

  Future<void> _showPhoto(
    FaunaLensPhoto photo,
    Future<GeoCoordinates?> Function() findLocation,
  ) async {
    state = state.copyWith(isBusy: false, photo: photo);
    await Future.wait([_stopCamera(), _resolveLocation(photo, findLocation)]);
  }

  Future<void> _stopCamera() async {
    _cameraRequest++;
    state = state.copyWith(cameraStatus: FaunaLensCameraStatus.stopped);
    await _camera.stop();
  }

  // A newly opened camera starts with its flash off. One without a flash stays
  // off rather than failing to open.
  Future<void> _restoreFlash() async {
    if (!state.isFlashOn) return;
    try {
      await _camera.setFlash(isOn: true);
    } catch (e) {
      debugPrint('FaunaLensViewModel: Failed to restore flash: $e');
      if (!_isDisposed) state = state.copyWith(isFlashOn: false);
    }
  }

  Future<void> _resolveLocation(
    FaunaLensPhoto photo,
    Future<GeoCoordinates?> Function() findLocation,
  ) async {
    GeoCoordinates? coordinates;
    try {
      coordinates = await findLocation();
    } catch (e) {
      debugPrint('FaunaLensViewModel: Failed to find photo location: $e');
    }
    // The user may have moved on to another photo during the lookup.
    if (_isDisposed || !identical(state.photo, photo)) return;
    state = state.copyWith(photo: photo.withLocation(coordinates));
  }
}

/// Provider exposing [FaunaLensViewModel]. Closing FaunaLens disposes it, which
/// releases the camera.
final faunaLensViewModelProvider =
    AutoDisposeNotifierProvider<FaunaLensViewModel, FaunaLensState>(
      FaunaLensViewModel.new,
    );
