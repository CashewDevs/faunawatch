import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:faunawatch/features/create_post/services/location_search_service.dart';
import 'location_picker_fakes.dart';

void main() {
  test(
    'requests storable geocoding results and maps names and coordinates',
    () async {
      final service = MapboxLocationSearchService(
        MockClient((request) async {
          expect(request.url.host, 'api.mapbox.com');
          expect(request.url.path, '/search/geocode/v6/forward');
          expect(request.url.queryParameters['q'], 'Cebu City');
          expect(request.url.queryParameters['permanent'], 'true');
          expect(request.url.queryParameters['autocomplete'], 'false');
          expect(request.url.queryParameters['proximity'], '123.8,10.4');
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'full_address': 'Cebu City, Philippines',
                    'coordinates': {'latitude': 10.3, 'longitude': 123.9},
                  },
                },
                {
                  'properties': {
                    'name': 'Invalid point',
                    'coordinates': {'latitude': 91, 'longitude': 123},
                  },
                },
              ],
            }),
            200,
          );
        }),
        accessToken: 'test-map-token',
      );
      final results = await service.search('  Cebu City  ', proximity: testPin);
      expect(results, hasLength(1));
      expect(results.single.label, testPlace.label);
      expect(results.single.latitude, testPlace.latitude);
      expect(results.single.longitude, testPlace.longitude);
    },
  );

  test(
    'does not send empty or invalid queries or missing-token requests',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      var service = MapboxLocationSearchService(client, accessToken: 'test');
      expect(await service.search('  '), isEmpty);
      await expectLater(
        service.search('a' * 257),
        throwsA(isA<LocationSearchException>()),
      );
      await expectLater(
        service.search('Cebu; City'),
        throwsA(isA<LocationSearchException>()),
      );
      service = MapboxLocationSearchService(client, accessToken: '');
      await expectLater(
        service.search('Cebu'),
        throwsA(isA<LocationSearchException>()),
      );
      expect(calls, 0);
    },
  );

  test(
    'empty results and HTTP failures do not expose token or response body',
    () async {
      final empty = MapboxLocationSearchService(
        MockClient((_) async => http.Response('{"features":[]}', 200)),
        accessToken: 'test',
      );
      expect(await empty.search('Nowhere'), isEmpty);
      for (final code in [401, 403, 429, 500]) {
        final service = MapboxLocationSearchService(
          MockClient(
            (_) async => http.Response('private response test-map-token', code),
          ),
          accessToken: 'test-map-token',
        );
        await expectLater(
          service.search('Cebu'),
          throwsA(
            isA<LocationSearchException>().having(
              (e) => e.message,
              'message',
              isNot(contains('test-map-token')),
            ),
          ),
        );
      }
    },
  );
}
