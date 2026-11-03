import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:faunawatch/core/constants/app_config.dart';
import '../models/post_location.dart';

abstract interface class LocationSearchService {
  Future<List<PostLocation>> search(String query, {PostLocation? proximity});
}

class LocationSearchException implements Exception {
  const LocationSearchException(this.message);
  final String message;
}

/// Permanent geocoding is necessary because the chosen point is saved in reports.
class MapboxLocationSearchService implements LocationSearchService {
  const MapboxLocationSearchService(this._client, {required this.accessToken});
  final http.Client _client;
  final String accessToken;

  @override
  Future<List<PostLocation>> search(
    String query, {
    PostLocation? proximity,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return [];
    if (text.length > 256 ||
        text.contains(';') ||
        text.split(RegExp(r'\s+')).length > 20) {
      throw const LocationSearchException('Try a shorter city or address.');
    }
    if (accessToken.isEmpty) {
      throw const LocationSearchException(
        'Place search is unavailable. You can still pin a location on the map.',
      );
    }
    try {
      final response = await _client
          .get(
            Uri.https('api.mapbox.com', '/search/geocode/v6/forward', {
              'q': text,
              'access_token': accessToken,
              'permanent': 'true',
              'autocomplete': 'false',
              'limit': '5',
              if (proximity?.isValid == true)
                'proximity': '${proximity!.longitude},${proximity.latitude}',
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const LocationSearchException(
          'Could not search places. Try again or pin the location on the map.',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = <PostLocation>[];
      for (final feature in data['features'] as List) {
        final properties = feature['properties'] as Map<String, dynamic>;
        final coordinates = properties['coordinates'] as Map<String, dynamic>;
        final latitude = coordinates['latitude'];
        final longitude = coordinates['longitude'];
        if (latitude is! num || longitude is! num) continue;
        final location = PostLocation(
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
          label:
              properties['full_address'] as String? ??
              [
                properties['name'],
                properties['place_formatted'],
              ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
        );
        if (location.isValid) results.add(location);
      }
      return List.unmodifiable(results);
    } on LocationSearchException {
      rethrow;
    } catch (_) {
      // Never expose HTTP exceptions: their request URI contains the access token.
      throw const LocationSearchException(
        'Could not search places. Check your connection or pin the location on the map.',
      );
    }
  }
}

final locationSearchServiceProvider =
    Provider.autoDispose<LocationSearchService>((ref) {
      final client = http.Client();
      ref.onDispose(client.close);
      return MapboxLocationSearchService(
        client,
        accessToken: AppConfig.mapboxPublicToken,
      );
    });
