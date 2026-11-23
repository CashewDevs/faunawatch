import 'dart:convert';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabasePublicProfileService service;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> rows, profiles;
  bool failSigning = false;

  Map<String, dynamic> postRow(String id) => {
    'id': id,
    'author_id': 'other',
    'author_name': 'Forest Ranger',
    'author_avatar_path': 'preset:panda',
    'category': 'animal_in_need',
    'user_species': 'Philippine Eagle',
    'created_at': '2026-11-19T04:00:00Z',
    'feed_at': '2026-11-20T05:00:00Z',
    'photo_paths': ['$id/photo.webp'],
  };

  setUp(() {
    requests = [];
    rows = [];
    profiles = [];
    failSigning = false;
    client = SupabaseClient(
      'https://public-profile-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body;
        var status = 200;
        final path = request.url.path;
        if (path.startsWith('/auth/')) {
          final payload = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({
                    'sub': 'me',
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
              'id': 'me',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        } else if (path == '/rest/v1/profiles') {
          body = profiles;
        } else if (path.endsWith('/rpc/public_profile_gallery')) {
          body = rows;
        } else if (path.contains('/object/sign/')) {
          status = failSigning ? 404 : 200;
          body = failSigning
              ? {'message': 'not found'}
              : {
                  'signedURL':
                      '${path.split('/storage/v1').last}?token=test-only',
                };
        } else {
          throw StateError('Unexpected request path: $path');
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    service = SupabasePublicProfileService(client);
  });
  tearDown(() => client.dispose());

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'viewer@example.com',
      password: 'test-password',
    );
    requests.clear();
  }

  test('signed-out access never sends a profile or gallery request', () async {
    expect(() => service.fetchProfile('other'), throwsA(isA<AuthException>()));
    await expectLater(
      service.fetchPosts('other'),
      throwsA(isA<AuthException>()),
    );
    expect(requests, isEmpty);
  });

  test('reads only public identity fields for the selected account', () async {
    await signIn();
    profiles = [
      {
        'username': 'Forest Ranger',
        'bio': 'Watching canopy birds',
        'avatar_path': 'preset:panda',
        'banner_asset': AppAssets.bannerDay,
        'banner_color': null,
      },
    ];
    final profile = await service.fetchProfile('other');
    expect(profile!.username, 'Forest Ranger');
    expect(profile.bio, 'Watching canopy birds');
    expect(profile.presetAvatar, AppAssets.avatarPanda);
    expect(profile.bannerAsset, AppAssets.bannerDay);
    final query = requests.single.url.queryParameters;
    expect(query['id'], 'eq.other');
    expect(
      query['select'],
      'username,full_name,display_name,bio,avatar_path,banner_asset,banner_color',
    );
    profiles = [];
    expect(await service.fetchProfile('gone'), isNull);
  });

  test(
    'author and category are filtered in the RPC with a submission cursor',
    () async {
      await signIn();
      rows = [postRow('a')];
      final first = await service.fetchPosts('other');
      expect(first.single.authorId, 'other');
      expect(first.single.authorAvatarAsset, AppAssets.avatarPanda);
      expect(first.single.photoUrls.single, contains('a/photo.webp'));
      final cursor = first.single;
      requests.clear();
      await service.fetchPosts(
        'other',
        before: cursor,
        category: ReportCategory.animalInNeed,
      );
      final request = requests.first;
      expect(request.url.path, '/rest/v1/rpc/public_profile_gallery');
      expect(jsonDecode(request.body), {
        'p_user_id': 'other',
        'p_before_at': cursor.createdAt.toUtc().toIso8601String(),
        'p_before_id': 'a',
        'p_limit': PublicProfileService.pageSize,
        'p_category': 'animal_in_need',
      });
      expect(cursor.feedAt, isNot(cursor.createdAt));
      expect(requests.where((r) => r.url.path.endsWith('/reports')), isEmpty);
    },
  );

  test('missing photos leave a usable gallery tile', () async {
    await signIn();
    rows = [postRow('a')];
    failSigning = true;
    final posts = await service.fetchPosts('other');
    expect(posts.single.title, 'Philippine Eagle');
    expect(posts.single.photoUrls, isEmpty);
    expect(posts.single.authorAvatarAsset, AppAssets.avatarPanda);
  });

  test('signed-out service has no cached identity or media', () async {
    const signedOut = SignedOutPublicProfileService();
    expect(await signedOut.fetchProfile('other'), isNull);
    expect(
      await signedOut.fetchPosts(
        'other',
        before: FeedPost.fromJson(postRow('a')),
      ),
      isEmpty,
    );
    expect(requests, isEmpty);
  });
}
