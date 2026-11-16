import 'dart:convert';

import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabaseGalleryService service;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> rows;
  late Set<String> missing;

  Map<String, dynamic> row(String id) => {
    'id': id,
    'user_id': 'user-a',
    'category': 'animal_in_need',
    'user_species': 'Eagle',
    'created_at': '2026-11-17T08:00:00Z',
    'place_name': 'Cebu City',
    'report_images': [],
    'ai_analyses': [],
  };

  setUp(() {
    requests = [];
    rows = [];
    missing = {};
    client = SupabaseClient(
      'https://gallery-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body;
        var status = 200;
        if (request.url.path.startsWith('/auth/')) {
          final payload = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({
                    'sub': 'user-a',
                    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                  }),
                ),
              )
              .replaceAll('=', '');
          body = {
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
          };
        } else if (request.url.path == '/rest/v1/reports') {
          body = rows;
        } else if (request.url.path.contains('/object/sign/')) {
          final path = request.url.path.split('/object/sign/').last;
          if (missing.any(path.endsWith)) {
            status = 404;
            body = {'message': 'missing'};
          } else {
            body = {'signedURL': '/object/sign/$path?token=test-only'};
          }
        } else {
          throw StateError('Unexpected gallery request');
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    service = SupabaseGalleryService(client);
  });
  tearDown(() => client.dispose());

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-only',
    );
    requests.clear();
  }

  test('signed-out access is empty and cannot issue a reports query', () async {
    await expectLater(service.fetchPage(), throwsA(isA<AuthException>()));
    expect(await const SignedOutGalleryService().fetchPage(), isEmpty);
    expect(requests, isEmpty);
  });

  test(
    'restricts queries to own approved posts with stable keyset paging',
    () async {
      await signIn();
      rows = [row('r1')];
      final posts = await service.fetchPage();
      final query = requests.single.url.queryParameters;
      expect(query['user_id'], 'eq.user-a');
      expect(query['status'], 'eq.approved');
      expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(query['limit'], '${GalleryService.pageSize}');
      expect(query['select'], isNot(contains('latitude')));
      expect(query['select'], isNot(contains('user_notes')));
      expect(posts.single.title, 'Eagle');
      expect(posts.single.authorId, 'user-a');
      expect(posts.single.location, 'Cebu City');
      requests.clear();
      await service.fetchPage(before: posts.single);
      expect(
        requests.single.url.queryParameters['or'],
        '(created_at.lt.2026-11-17T08:00:00.000Z,'
        'and(created_at.eq.2026-11-17T08:00:00.000Z,id.lt.r1))',
      );
    },
  );

  test(
    'uses the completed AI title and first signable private photo',
    () async {
      await signIn();
      rows = [
        {
          ...row('r1'),
          'user_species': '',
          'ai_analyses': [
            {
              'status': 'failed',
              'possible_species': [
                {'common_name': 'Ignore'},
              ],
            },
            {
              'status': 'completed',
              'possible_species': [
                {'common_name': 'Owl'},
              ],
            },
          ],
          'report_images': [
            {'storage_path': 'r1/missing.webp'},
            {'storage_path': 'r1/available.webp'},
            {'storage_path': 'r1/unneeded.webp'},
          ],
        },
      ];
      missing.add('missing.webp');
      final post = (await service.fetchPage()).single;
      expect(post.title, 'Owl');
      expect(post.photoUrls.single, contains('r1/available.webp'));
      final signing = requests.where(
        (request) => request.url.path.contains('/sign/'),
      );
      expect(signing, hasLength(2));
      expect(jsonDecode(signing.last.body)['expiresIn'], 3600);
      expect(
        requests.first.url.queryParameters['report_images.order'],
        'created_at.asc.nullslast,id.asc.nullslast',
      );
    },
  );

  test('missing photos and analysis keep a usable category card', () async {
    await signIn();
    rows = [
      {
        ...row('r1'),
        'user_species': null,
        'place_name': null,
        'report_images': [
          {'storage_path': 'r1/missing.webp'},
        ],
      },
    ];
    missing.add('missing.webp');
    final post = (await service.fetchPage()).single;
    expect(post.title, 'Animal in need');
    expect(post.photoUrls, isEmpty);
    expect(post.location, FeedPost.approximateLocation);
  });
}
