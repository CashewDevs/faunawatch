import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:faunawatch/core/constants/app_config.dart';

abstract interface class PlaceNameService {
  /// The area around a point, or null when it can't be determined. Never
  /// throws: a post must still submit without a place name.
  Future<String?> lookup(double latitude, double longitude);
}

/// Reverse geocodes a report's point to its area, e.g. "Lusod, Kabayan, Benguet".
///
/// Permanent geocoding is necessary because the name is saved in reports. Only
/// the area names are read, never full_address or the address and street
/// context, so a street address can't be stored.
class MapboxPlaceNameService implements PlaceNameService {
  const MapboxPlaceNameService(this._client, {required this.accessToken});
  final http.Client _client;
  final String accessToken;

  /// Matches the reports_place_name_length check in the database.
  static const maxLength = 200;

  /// Barangay or locality, city, province, most specific first.
  static const _areaTypes = ['locality', 'place', 'region'];

  @override
  Future<String?> lookup(double latitude, double longitude) async {
    if (accessToken.isEmpty) return null;
    try {
      final response = await _client
          .get(
            Uri.https('api.mapbox.com', '/search/geocode/v6/reverse', {
              'longitude': '$longitude',
              'latitude': '$latitude',
              'types': _areaTypes.join(','),
              'permanent': 'true',
              'access_token': accessToken,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List;
      if (features.isEmpty) return null;
      // Results run from most to least specific, and the most specific one's
      // context already holds the larger areas around it.
      final properties = features.first['properties'] as Map<String, dynamic>;
      return _areaName(properties['context'] as Map<String, dynamic>);
    } catch (_) {
      // Never expose HTTP exceptions: their request URI contains the access token.
      return null;
    }
  }

  String? _areaName(Map<String, dynamic> context) {
    final names = <String>[];
    for (final type in _areaTypes) {
      final name = (context[type]?['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      // Some cities are also their own region, e.g. Manila.
      final isRepeat = names.any(
        (existing) => existing.toLowerCase() == name.toLowerCase(),
      );
      if (!isRepeat) names.add(name);
    }
    final areaName = names.join(', ');
    return areaName.isEmpty || areaName.length > maxLength ? null : areaName;
  }
}

final placeNameServiceProvider = Provider<PlaceNameService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return MapboxPlaceNameService(
    client,
    accessToken: AppConfig.mapboxPublicToken,
  );
});
