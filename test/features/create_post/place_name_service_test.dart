import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:faunawatch/features/create_post/services/place_name_service.dart';

Map<String, dynamic> _feature(Map<String, String> context) => {
  'properties': {
    'context': {
      for (final entry in context.entries) entry.key: {'name': entry.value},
    },
  },
};

MapboxPlaceNameService _serviceReturning(List<Map<String, dynamic>> features) =>
    MapboxPlaceNameService(
      MockClient(
        (_) async => http.Response(jsonEncode({'features': features}), 200),
      ),
      accessToken: 'test-map-token',
    );

void main() {
  test('requests storable area results for the exact point', () async {
    final service = MapboxPlaceNameService(
      MockClient((request) async {
        expect(request.url.host, 'api.mapbox.com');
        expect(request.url.path, '/search/geocode/v6/reverse');
        expect(request.url.queryParameters['latitude'], '16.5967');
        expect(request.url.queryParameters['longitude'], '120.8986');
        expect(request.url.queryParameters['types'], 'locality,place,region');
        expect(request.url.queryParameters['permanent'], 'true');
        return http.Response('{"features":[]}', 200);
      }),
      accessToken: 'test-map-token',
    );
    await service.lookup(16.5967, 120.8986);
  });

  // Context values below come from real Mapbox responses for these places.
  test('builds the name from locality, city and province', () async {
    final service = _serviceReturning([
      _feature({
        'locality': 'Lusod',
        'place': 'Kabayan',
        'region': 'Benguet',
        'country': 'Philippines',
      }),
      _feature({'place': 'Kabayan', 'region': 'Benguet'}),
      _feature({'region': 'Benguet'}),
    ]);
    expect(await service.lookup(16.5967, 120.8986), 'Lusod, Kabayan, Benguet');
  });

  test('leaves out a city that is also its own region', () async {
    final service = _serviceReturning([
      _feature({
        'locality': 'Barangay 666',
        'place': 'Manila',
        'region': 'Manila',
        'country': 'Philippines',
      }),
    ]);
    expect(await service.lookup(14.5831, 120.9794), 'Barangay 666, Manila');
  });

  test('uses whatever areas exist, such as only a province', () async {
    final service = _serviceReturning([
      _feature({'region': 'Bataan', 'country': 'Philippines'}),
    ]);
    expect(await service.lookup(14.5, 120.7), 'Bataan');
  });

  test('never reads a street address or other detail', () async {
    final service = MapboxPlaceNameService(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'features': [
              {
                'properties': {
                  'name': '12 Sampaguita Street',
                  'full_address': '12 Sampaguita Street, Lusod, Kabayan',
                  'place_formatted': 'Lusod, Kabayan, Benguet 2606',
                  'context': {
                    'address': {
                      'name': '12 Sampaguita Street',
                      'address_number': '12',
                      'street_name': 'Sampaguita Street',
                    },
                    'street': {'name': 'Sampaguita Street'},
                    'neighborhood': {'name': 'Purok 3'},
                    'postcode': {'name': '2606'},
                    'locality': {'name': 'Lusod'},
                    'place': {'name': 'Kabayan'},
                    'district': {'name': 'Some District'},
                    'region': {'name': 'Benguet'},
                    'country': {'name': 'Philippines'},
                  },
                },
              },
            ],
          }),
          200,
        ),
      ),
      accessToken: 'test-map-token',
    );
    expect(await service.lookup(16.5967, 120.8986), 'Lusod, Kabayan, Benguet');
  });

  test('ignores blank names', () async {
    final service = _serviceReturning([
      _feature({'locality': '  ', 'place': ' Kabayan ', 'region': 'Benguet'}),
    ]);
    expect(await service.lookup(16.5967, 120.8986), 'Kabayan, Benguet');
  });

  group('returns null without failing', () {
    test('when the point has no area', () async {
      expect(await _serviceReturning([]).lookup(0, 0), isNull);
      expect(await _serviceReturning([_feature({})]).lookup(0, 0), isNull);
    });

    test('when the name is longer than the database allows', () async {
      final atLimit = _serviceReturning([
        _feature({'region': 'x' * MapboxPlaceNameService.maxLength}),
      ]);
      expect(await atLimit.lookup(0, 0), hasLength(200));

      final overLimit = _serviceReturning([
        _feature({'region': 'x' * (MapboxPlaceNameService.maxLength + 1)}),
      ]);
      expect(await overLimit.lookup(0, 0), isNull);
    });

    test('on an error response, including no card on file', () async {
      for (final code in [401, 402, 403, 422, 429, 500]) {
        final service = MapboxPlaceNameService(
          MockClient((_) async => http.Response('{"message":"no"}', code)),
          accessToken: 'test-map-token',
        );
        expect(await service.lookup(0, 0), isNull);
      }
    });

    test('on a response in an unexpected shape', () async {
      for (final body in [
        'not json',
        '[]',
        '{}',
        '{"features":"nope"}',
        '{"features":[{}]}',
        '{"features":[{"properties":{}}]}',
        '{"features":[{"properties":{"context":{"place":"Manila"}}}]}',
        '{"features":[{"properties":{"context":{"place":{"name":5}}}}]}',
      ]) {
        final service = MapboxPlaceNameService(
          MockClient((_) async => http.Response(body, 200)),
          accessToken: 'test-map-token',
        );
        expect(await service.lookup(0, 0), isNull, reason: body);
      }
    });

    test('on a network failure', () async {
      final service = MapboxPlaceNameService(
        MockClient(
          (request) async => throw http.ClientException('offline', request.url),
        ),
        accessToken: 'test-map-token',
      );
      expect(await service.lookup(0, 0), isNull);
    });
  });

  test('sends nothing without a token', () async {
    var calls = 0;
    final service = MapboxPlaceNameService(
      MockClient((_) async {
        calls++;
        return http.Response('{"features":[]}', 200);
      }),
      accessToken: '',
    );
    expect(await service.lookup(14.5, 120.7), isNull);
    expect(calls, 0);
  });
}
