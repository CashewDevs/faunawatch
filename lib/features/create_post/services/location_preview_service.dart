import 'package:faunawatch/core/constants/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_location.dart';

/// Builds the link to a still picture of the map around an observation point,
/// with a pin on it, from the Mapbox Static Images API.
///
/// Uses the same public token as the maps. The picture is only shown on the
/// form; nothing is saved.
class LocationPreviewService {
  const LocationPreviewService({this.token = AppConfig.mapboxPublicToken});

  /// Mapbox's largest picture side, before the @2x sharpening.
  static const maxSide = 1280;

  /// How close the picture is: street level around a pin, the whole region
  /// without one.
  static const pinnedZoom = 14.0;
  static const regionZoom = 4.5;

  /// The pin's colour, as Mapbox expects it (hex without #).
  static const pinColor = '1a5dc9';

  final String token;

  /// The picture link for a [width] x [height] (logical pixels) map around
  /// [location], or the whole region when it is null. Null when no Mapbox
  /// token is configured.
  Uri? previewUrl({
    required PostLocation? location,
    required int width,
    required int height,
    required bool isDarkMode,
  }) {
    if (token.isEmpty || width <= 0 || height <= 0) return null;
    final center = location ?? PostLocation.regionalFallback;
    final lon = center.longitude.toStringAsFixed(5);
    final lat = center.latitude.toStringAsFixed(5);
    final style = isDarkMode ? 'dark-v11' : 'streets-v12';
    final pin = location == null ? '' : 'pin-l+$pinColor($lon,$lat)/';
    final zoom = location == null ? regionZoom : pinnedZoom;
    final w = width.clamp(1, maxSide);
    final h = height.clamp(1, maxSide);
    return Uri.https(
      'api.mapbox.com',
      '/styles/v1/mapbox/$style/static/$pin$lon,$lat,$zoom,0/${w}x$h@2x',
      {'access_token': token},
    );
  }
}

final locationPreviewServiceProvider = Provider<LocationPreviewService>(
  (ref) => const LocationPreviewService(),
);
