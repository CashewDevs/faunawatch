import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/services/create_post_service.dart';
import 'package:faunawatch/features/create_post/services/place_name_service.dart';
import 'package:faunawatch/features/create_post/services/post_photo_service.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';

import '../fauna_lens/ai_fakes.dart';

class _Photos implements PostPhotoService {
  int size = 3;
  @override
  Future<PreparedPostPhoto> prepare(String path) async => PreparedPostPhoto(
    bytes: Uint8List(size),
    fingerprint: 'test-fingerprint',
    exif: {'gps_latitude': 10.1234, 'gps_longitude': 123.1234},
  );
}

class _PlaceNames implements PlaceNameService {
  String? name = 'Lusod, Kabayan, Benguet';
  final lookups = <(double, double)>[];
  @override
  Future<String?> lookup(double latitude, double longitude) async {
    lookups.add((latitude, longitude));
    return name;
  }
}

List<int> _uploadedPhotoBytes(dynamic body) {
  final bytes = body as List<int>;
  final multipart = latin1.decode(bytes);
  final fileHeader = multipart.indexOf('filename=""');
  expect(fileHeader, greaterThanOrEqualTo(0));
  final start = multipart.indexOf('\r\n\r\n', fileHeader) + 4;
  final end = multipart.lastIndexOf('\r\n--');
  return bytes.sublist(start, end);
}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseCreatePostService service;
  late _Photos photos;
  late _PlaceNames placeNames;
  late List<(String, String, dynamic)> requests;
  String? failPath;
  const draft = PostDraft(
    category: ReportCategory.animalInNeed,
    latitude: 10.1234,
    longitude: 123.1234,
    description: 'Bird',
  );

  setUp(() async {
    requests = [];
    failPath = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final bytes = await request.fold<List<int>>(
        [],
        (all, part) => all..addAll(part),
      );
      final body =
          request.headers.contentType?.mimeType == 'application/json' &&
              bytes.isNotEmpty
          ? jsonDecode(utf8.decode(bytes))
          : bytes;
      requests.add((request.method, request.uri.path, body));
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == failPath && request.method == 'POST') {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({'message': 'test failure'}));
      } else if (request.uri.path.startsWith('/auth/')) {
        final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        final payload = base64Url
            .encode(utf8.encode(jsonEncode({'sub': 'user-a', 'exp': expiry})))
            .replaceAll('=', '');
        request.response.write(
          jsonEncode({
            'access_token': 'e30.$payload.test',
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'user-a',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
        );
      } else if (request.uri.path == '/rest/v1/rpc/community_reports') {
        request.response.write(
          jsonEncode([
            {
              'id': 'approved',
              'category': 'animal_in_need',
              'description': 'Bird',
              'latitude': 10.12,
              'longitude': 123.12,
            },
          ]),
        );
      } else if (request.uri.path.startsWith('/storage/')) {
        request.response.write(jsonEncode({'Key': 'test-path'}));
      } else if (request.method == 'POST') {
        request.response.write(
          jsonEncode({
            'id': request.uri.path.endsWith('reports') ? 'report-1' : 'image-1',
          }),
        );
      } else {
        request.response.write('[]');
      }
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');
    photos = _Photos();
    placeNames = _PlaceNames();
    service = SupabaseCreatePostService(client, photos, placeNames);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-password',
    );
    requests.clear();
  }

  test('requires authentication before writing anything', () async {
    await expectLater(
      service.submit(draft),
      throwsA(isA<PostSubmissionException>()),
    );
    expect(requests, isEmpty);
    expect(placeNames.lookups, isEmpty);
  });

  test(
    'saves required location to reports and keeps moderation pending',
    () async {
      await signIn();
      expect(await service.submit(draft), 'report-1');
      final row = requests.single.$3 as Map;
      expect(row['user_id'], 'user-a');
      expect(row['latitude'], 10.1234);
      expect(row['longitude'], 123.1234);
      expect(row['status'], 'pending');
      expect(row['ai_status'], 'unavailable');
    },
  );

  test('looks up the final point once and saves its area name', () async {
    await signIn();
    await service.submit(draft);
    expect(placeNames.lookups, [(10.1234, 123.1234)]);
    expect(
      (requests.single.$3 as Map)['place_name'],
      'Lusod, Kabayan, Benguet',
    );
  });

  test('still submits the post when the area is unknown', () async {
    await signIn();
    placeNames.name = null;
    expect(await service.submit(draft), 'report-1');
    final row = requests.single.$3 as Map;
    expect(row.containsKey('place_name'), isTrue);
    expect(row['place_name'], isNull);
  });

  test('uploads private processed photo and stores EXIF separately', () async {
    await signIn();
    await service.submit(
      const PostDraft(
        category: ReportCategory.animalInNeed,
        latitude: 10,
        longitude: 123,
        photoPath: 'original.jpg',
      ),
    );
    expect(requests.map((r) => r.$2), [
      '/rest/v1/reports',
      '/storage/v1/object/report-images/report-1/photo.webp',
      '/rest/v1/report_images',
      '/rest/v1/report_image_exif',
    ]);
    final image = requests[2].$3 as Map;
    // No user id in the path, so shared photos don't reveal the reporter.
    expect(image['storage_path'], 'report-1/photo.webp');
    expect(image['content_type'], 'image/webp');
    expect(latin1.decode(requests[1].$3 as List<int>), contains('image/webp'));
    expect(image['size_bytes'], photos.size);
    expect(_uploadedPhotoBytes(requests[1].$3), List.filled(photos.size, 0));
    expect(image['fingerprint'], 'test-fingerprint');
    expect(image.containsKey('gps_latitude'), isFalse);
    expect((requests[3].$3 as Map)['gps_latitude'], 10.1234);
  });

  test('metadata failure removes uploaded object and partial report', () async {
    await signIn();
    failPath = '/rest/v1/report_images';
    await expectLater(
      service.submit(
        const PostDraft(
          category: ReportCategory.animalInNeed,
          latitude: 10,
          longitude: 123,
          photoPath: 'original.jpg',
        ),
      ),
      throwsA(isA<PostSubmissionException>()),
    );
    final deletes = requests.where((r) => r.$1 == 'DELETE').toList();
    expect(deletes.map((r) => r.$2), [
      '/storage/v1/object/report-images',
      '/rest/v1/reports',
    ]);
  });

  group('FaunaLens analysis', () {
    final withAnalysis = PostDraft(
      category: ReportCategory.possibleInvasiveSpecies,
      latitude: 10,
      longitude: 123,
      photoPath: 'original.jpg',
      aiResult: sampleIdentification(invasive: true),
    );

    test('is saved to ai_analyses after the report and its photo', () async {
      await signIn();
      expect(await service.submit(withAnalysis), 'report-1');
      expect(requests.map((r) => r.$2), [
        '/rest/v1/reports',
        '/storage/v1/object/report-images/report-1/photo.webp',
        '/rest/v1/report_images',
        '/rest/v1/report_image_exif',
        '/rest/v1/ai_analyses',
      ]);
      final report = requests.first.$3 as Map;
      expect(report['status'], 'pending');
      expect(report['ai_status'], 'completed');
      final analysis = requests.last.$3 as Map;
      expect(analysis['report_id'], 'report-1');
      expect(analysis['status'], 'completed');
      expect(analysis['severity'], 'low');
      expect(analysis['possible_invasive'], isTrue);
      expect(analysis['invasive_match_species_id'], sampleInvasiveMatch.id);
      expect((analysis['possible_species'] as List).first, {
        'common_name': 'Red-eared Slider',
        'scientific_name': 'Trachemys scripta elegans',
        'confidence': 'medium',
      });
    });

    test('a failed analysis insert removes the photo and report', () async {
      await signIn();
      failPath = '/rest/v1/ai_analyses';
      await expectLater(
        service.submit(withAnalysis),
        throwsA(isA<PostSubmissionException>()),
      );
      final deletes = requests.where((r) => r.$1 == 'DELETE').toList();
      expect(deletes.map((r) => r.$2), [
        '/storage/v1/object/report-images',
        '/rest/v1/reports',
      ]);
    });

    test('is not saved without the photo it describes', () async {
      await signIn();
      await service.submit(
        PostDraft(
          category: ReportCategory.animalInNeed,
          latitude: 10,
          longitude: 123,
          aiResult: sampleIdentification(),
        ),
      );
      expect(requests.map((r) => r.$2), ['/rest/v1/reports']);
      expect((requests.single.$3 as Map)['ai_status'], 'unavailable');
    });
  });

  test(
    'processed upload over 5 MB is rejected before any remote write',
    () async {
      await signIn();
      photos.size = DevicePostPhotoService.maxBytes + 1;
      await expectLater(
        service.submit(
          const PostDraft(
            category: ReportCategory.animalInNeed,
            latitude: 10,
            longitude: 123,
            photoPath: 'original.jpg',
          ),
        ),
        throwsA(
          isA<PostSubmissionException>().having(
            (e) => e.message,
            'message',
            contains('5 MB'),
          ),
        ),
      );
      expect(requests, isEmpty);
      expect(placeNames.lookups, isEmpty);
    },
  );

  test('an upload of exactly 5 MB is stored and its size recorded', () async {
    await signIn();
    photos.size = DevicePostPhotoService.maxBytes;
    await service.submit(
      const PostDraft(
        category: ReportCategory.animalInNeed,
        latitude: 10,
        longitude: 123,
        photoPath: 'original.jpg',
      ),
    );
    expect(
      _uploadedPhotoBytes(requests[1].$3).length,
      DevicePostPhotoService.maxBytes,
    );
    expect(
      (requests[2].$3 as Map)['size_bytes'],
      DevicePostPhotoService.maxBytes,
    );
  });

  test(
    'invalid location cannot reach database even outside ViewModel',
    () async {
      await signIn();
      await expectLater(
        service.submit(
          const PostDraft(
            category: ReportCategory.animalInNeed,
            latitude: 100,
            longitude: 0,
          ),
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
      expect(placeNames.lookups, isEmpty);
    },
  );

  test(
    'map reads the public RPC and displays its approximate coordinates',
    () async {
      final reports = await SupabaseCommunityReportsService(client).load();
      expect(requests.single.$2, '/rest/v1/rpc/community_reports');
      expect(reports.single.latitude, 10.12);
      expect(reports.single.post.author, 'Community spotter');
      expect(reports.single.post.location, contains('Approximate location'));
    },
  );
}
