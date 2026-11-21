import 'package:faunawatch/features/create_post/models/post_location.dart';
import 'package:faunawatch/features/create_post/services/location_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = LocationPreviewService(token: 'pk.test');
  const cebu = PostLocation(latitude: 10.3157, longitude: 123.8854);

  test('a chosen location gets a street-level picture with its pin', () {
    final url = service.previewUrl(
      location: cebu,
      width: 350,
      height: 180,
      isDarkMode: false,
    )!;
    expect(url.host, 'api.mapbox.com');
    expect(
      url.path,
      '/styles/v1/mapbox/streets-v12/static/'
      'pin-l+1a5dc9(123.88540,10.31570)/123.88540,10.31570,14.0,0/350x180@2x',
    );
    expect(url.queryParameters['access_token'], 'pk.test');
  });

  test('dark mode uses the dark map', () {
    final url = service.previewUrl(
      location: cebu,
      width: 350,
      height: 180,
      isDarkMode: true,
    )!;
    expect(url.path, startsWith('/styles/v1/mapbox/dark-v11/static/'));
  });

  test('without a location it shows the region and no pin', () {
    final url = service.previewUrl(
      location: null,
      width: 350,
      height: 180,
      isDarkMode: false,
    )!;
    expect(url.path, isNot(contains('pin-')));
    expect(url.path, contains('122.00000,12.00000,4.5,0'));
  });

  test('sizes stay within what Mapbox accepts', () {
    final url = service.previewUrl(
      location: cebu,
      width: 4000,
      height: 180,
      isDarkMode: false,
    )!;
    expect(url.path, endsWith('/1280x180@2x'));
    expect(
      service.previewUrl(
        location: cebu,
        width: 0,
        height: 180,
        isDarkMode: false,
      ),
      isNull,
    );
  });

  test('nothing is shown without a token', () {
    expect(
      const LocationPreviewService(
        token: '',
      ).previewUrl(location: cebu, width: 350, height: 180, isDarkMode: false),
      isNull,
    );
  });
}
