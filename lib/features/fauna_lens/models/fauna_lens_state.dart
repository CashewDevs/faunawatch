/// Whether the live camera preview can be shown.
enum FaunaLensCameraStatus { starting, ready, stopped, unavailable }

/// Where the photo under review came from.
enum FaunaLensPhotoSource { camera, gallery }

/// Progress of finding where the photo under review was taken.
enum FaunaLensLocationStatus { locating, found, missing }

/// A latitude/longitude pair in decimal degrees.
class GeoCoordinates {
  const GeoCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// A captured or selected photo waiting for the user's decision.
class FaunaLensPhoto {
  const FaunaLensPhoto({
    required this.path,
    required this.source,
    this.locationStatus = FaunaLensLocationStatus.locating,
    this.coordinates,
  });

  final String path;
  final FaunaLensPhotoSource source;
  final FaunaLensLocationStatus locationStatus;
  final GeoCoordinates? coordinates;

  /// Returns this photo with the result of the location lookup applied.
  FaunaLensPhoto withLocation(GeoCoordinates? coordinates) {
    return FaunaLensPhoto(
      path: path,
      source: source,
      locationStatus: coordinates == null
          ? FaunaLensLocationStatus.missing
          : FaunaLensLocationStatus.found,
      coordinates: coordinates,
    );
  }
}

/// Presentation state for the FaunaLens camera and photo review screens.
class FaunaLensState {
  const FaunaLensState({
    this.cameraStatus = FaunaLensCameraStatus.starting,
    this.isFlashOn = false,
    this.isBusy = false,
    this.photo,
  });

  final FaunaLensCameraStatus cameraStatus;
  final bool isFlashOn;
  final bool isBusy;
  final FaunaLensPhoto? photo;

  FaunaLensState copyWith({
    FaunaLensCameraStatus? cameraStatus,
    bool? isFlashOn,
    bool? isBusy,
    FaunaLensPhoto? photo,
    bool clearPhoto = false,
  }) {
    return FaunaLensState(
      cameraStatus: cameraStatus ?? this.cameraStatus,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isBusy: isBusy ?? this.isBusy,
      photo: clearPhoto ? null : photo ?? this.photo,
    );
  }
}
