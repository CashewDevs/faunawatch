import 'dart:async';

import 'package:camera/camera.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/fauna_lens_camera_service.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import 'package:faunawatch/features/fauna_lens/viewmodels/fauna_lens_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _here = GeoCoordinates(latitude: 14.6, longitude: 121.0);

void main() {
  late _FakeCamera camera;
  late _FakeLocations locations;
  late _FakePicker picker;
  late ProviderContainer container;

  FaunaLensViewModel viewModel() =>
      container.read(faunaLensViewModelProvider.notifier);
  FaunaLensState state() => container.read(faunaLensViewModelProvider);

  setUp(() {
    camera = _FakeCamera();
    locations = _FakeLocations();
    picker = _FakePicker();
    container = ProviderContainer(
      overrides: [
        faunaLensCameraServiceProvider.overrideWithValue(camera),
        photoLocationServiceProvider.overrideWithValue(locations),
        imagePickerServiceProvider.overrideWithValue(picker),
      ],
    );
    container.listen(faunaLensViewModelProvider, (_, _) {});
    addTearDown(container.dispose);
  });

  group('camera', () {
    test('becomes ready after starting', () async {
      await viewModel().startCamera();
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
    });

    test('reports unavailable when it cannot open, and can retry', () async {
      camera.startError = CameraException('CameraAccessDenied', null);
      await viewModel().startCamera();
      expect(state().cameraStatus, FaunaLensCameraStatus.unavailable);

      camera.startError = null;
      await viewModel().startCamera();
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
    });

    test('closes in the background and reopens on return', () async {
      await viewModel().startCamera();
      await viewModel().pauseCamera();
      expect(state().cameraStatus, FaunaLensCameraStatus.stopped);
      expect(camera.isOpen, isFalse);

      await viewModel().resumeCamera();
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
      expect(camera.isOpen, isTrue);
    });

    test('does not retry on return when permission was denied', () async {
      camera.startError = CameraException('CameraAccessDenied', null);
      await viewModel().startCamera();
      await viewModel().pauseCamera();
      await viewModel().resumeCamera();
      expect(camera.startCalls, 1);
      expect(state().cameraStatus, FaunaLensCameraStatus.unavailable);
    });

    test('releases the camera when FaunaLens closes', () async {
      await viewModel().startCamera();
      container.dispose();
      expect(camera.isOpen, isFalse);
    });
  });

  group('flash', () {
    test('toggles on and off', () async {
      await viewModel().startCamera();
      expect(await viewModel().toggleFlash(), isTrue);
      expect(state().isFlashOn, isTrue);
      expect(await viewModel().toggleFlash(), isTrue);
      expect(state().isFlashOn, isFalse);
    });

    test('stays off and reports failure on a camera with no flash', () async {
      await viewModel().startCamera();
      camera.flashError = CameraException('setFlashModeFailed', null);
      expect(await viewModel().toggleFlash(), isFalse);
      expect(state().isFlashOn, isFalse);
    });

    test('turns off when switching to a camera with no flash', () async {
      await viewModel().startCamera();
      await viewModel().toggleFlash();
      camera.flashError = CameraException('setFlashModeFailed', null);
      expect(await viewModel().switchLens(), isTrue);
      expect(state().isFlashOn, isFalse);
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
    });
  });

  group('switching camera', () {
    test('switches and returns to ready', () async {
      await viewModel().startCamera();
      expect(await viewModel().switchLens(), isTrue);
      expect(camera.switchCalls, 1);
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
      expect(state().isBusy, isFalse);
    });

    test('reports when there is no other camera', () async {
      camera.hasOtherCamera = false;
      await viewModel().startCamera();
      expect(await viewModel().switchLens(), isFalse);
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
    });
  });

  group('capture', () {
    test('reviews the photo with its location and closes the camera', () async {
      locations.current = _here;
      await viewModel().startCamera();
      expect(await viewModel().capture(), isTrue);

      final photo = state().photo!;
      expect(photo.path, 'camera.jpg');
      expect(photo.source, FaunaLensPhotoSource.camera);
      expect(photo.locationStatus, FaunaLensLocationStatus.found);
      expect(photo.coordinates, same(_here));
      expect(camera.isOpen, isFalse);
    });

    test('shows no location when the lookup finds or fails to find', () async {
      await viewModel().startCamera();
      await viewModel().capture();
      expect(state().photo!.locationStatus, FaunaLensLocationStatus.missing);

      await viewModel().discardPhoto();
      locations.error = TimeoutException('GPS');
      await viewModel().capture();
      expect(state().photo!.locationStatus, FaunaLensLocationStatus.missing);
    });

    test('stays on the camera and reports failure when it fails', () async {
      camera.captureError = CameraException('captureFailed', null);
      await viewModel().startCamera();
      expect(await viewModel().capture(), isFalse);
      expect(state().photo, isNull);
      expect(state().isBusy, isFalse);
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
    });

    test('ignores the shutter until the camera is ready', () async {
      expect(await viewModel().capture(), isTrue);
      expect(camera.captureCalls, 0);
    });

    test('retaking clears the photo and reopens the camera', () async {
      await viewModel().startCamera();
      await viewModel().capture();
      await viewModel().discardPhoto();
      expect(state().photo, isNull);
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
      expect(camera.isOpen, isTrue);
    });

    test('ignores a location that arrives after retaking', () async {
      final pending = Completer<GeoCoordinates?>();
      locations.pendingCurrent = pending;
      await viewModel().startCamera();
      unawaited(viewModel().capture());
      await pumpEventQueue();
      expect(state().photo!.locationStatus, FaunaLensLocationStatus.locating);

      await viewModel().discardPhoto();
      pending.complete(_here);
      await pumpEventQueue();
      expect(state().photo, isNull);
    });
  });

  group('gallery', () {
    test('reviews the picked photo with the location saved in it', () async {
      picker.path = 'gallery.jpg';
      locations.inPhoto = _here;
      await viewModel().startCamera();
      await viewModel().pickFromGallery();

      final photo = state().photo!;
      expect(photo.path, 'gallery.jpg');
      expect(photo.source, FaunaLensPhotoSource.gallery);
      expect(photo.locationStatus, FaunaLensLocationStatus.found);
      expect(locations.lookedUpPath, 'gallery.jpg');
      expect(camera.isOpen, isFalse);
    });

    test('marks the location missing when the photo has none', () async {
      picker.path = 'gallery.jpg';
      await viewModel().pickFromGallery();
      expect(state().photo!.locationStatus, FaunaLensLocationStatus.missing);
    });

    test('cancelling keeps the camera open', () async {
      await viewModel().startCamera();
      await viewModel().pickFromGallery();
      expect(state().photo, isNull);
      expect(state().isBusy, isFalse);
      expect(state().cameraStatus, FaunaLensCameraStatus.ready);
    });

    test('cancelling Choose another keeps the current photo', () async {
      picker.path = 'first.jpg';
      await viewModel().pickFromGallery();
      picker.path = null;
      await viewModel().pickFromGallery();
      expect(state().photo!.path, 'first.jpg');
    });

    test('a picker failure leaves the camera usable', () async {
      picker.error = StateError('picker failed');
      await viewModel().startCamera();
      await viewModel().pickFromGallery();
      expect(state().photo, isNull);
      expect(state().isBusy, isFalse);
    });
  });
}

class _FakeCamera implements FaunaLensCameraService {
  bool isOpen = false;
  bool hasOtherCamera = true;
  int startCalls = 0;
  int switchCalls = 0;
  int captureCalls = 0;
  Object? startError;
  Object? flashError;
  Object? captureError;

  @override
  CameraController? get controller => null;

  @override
  Future<void> start() async {
    startCalls++;
    if (startError case final error?) throw error;
    isOpen = true;
  }

  @override
  Future<void> stop() async => isOpen = false;

  @override
  Future<bool> switchLens() async {
    switchCalls++;
    return hasOtherCamera;
  }

  @override
  Future<void> setFlash({required bool isOn}) async {
    if (flashError case final error?) throw error;
  }

  @override
  Future<String> takePicture() async {
    captureCalls++;
    if (captureError case final error?) throw error;
    return 'camera.jpg';
  }
}

class _FakeLocations implements PhotoLocationService {
  GeoCoordinates? current;
  GeoCoordinates? inPhoto;
  Object? error;
  Completer<GeoCoordinates?>? pendingCurrent;
  String? lookedUpPath;

  @override
  Future<GeoCoordinates?> currentLocation() async {
    if (error case final error?) throw error;
    if (pendingCurrent case final pending?) return pending.future;
    return current;
  }

  @override
  Future<GeoCoordinates?> locationInPhoto(String path) async {
    lookedUpPath = path;
    return inPhoto;
  }
}

class _FakePicker implements ImagePickerService {
  String? path;
  Object? error;

  @override
  Future<String?> pickImage() async {
    if (error case final error?) throw error;
    return path;
  }
}
