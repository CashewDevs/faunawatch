import 'package:faunawatch/core/services/map_pin_image.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a report's photo into its map pin picture.
abstract interface class MapPinPhotoService {
  /// The pin picture for [photoPath] in `report-images`, or null when the
  /// photo cannot be read or decoded (the pin then keeps the logo).
  Future<StyleImage?> loadPin(String photoPath);
}

/// Downloads the photo with the signed-in user's access. The storage rules
/// let every signed-in user read photos of approved reports, which are the
/// only ones `community_reports()` returns.
class SupabaseMapPinPhotoService implements MapPinPhotoService {
  const SupabaseMapPinPhotoService(this._client);
  final SupabaseClient _client;

  @override
  Future<StyleImage?> loadPin(String photoPath) async {
    try {
      final bytes = await _client.storage
          .from('report-images')
          .download(photoPath);
      return await createPhotoPinImage(bytes);
    } catch (_) {
      return null;
    }
  }
}

final mapPinPhotoServiceProvider = Provider<MapPinPhotoService>(
  (ref) => SupabaseMapPinPhotoService(ref.read(supabaseClientProvider)),
);
