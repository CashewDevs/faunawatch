import 'dart:convert';

import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabaseFeedService service;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> feedRows, commentRows;
  Map<String, dynamic>? insertedComment;
  Set<String> unsignable = {};
  Object? failLikes;

  Map<String, dynamic> feedRow(
    String id, {
    String? avatar,
    List<String>? photos,
    Map<String, dynamic>? more,
  }) => {
    'id': id,
    'category': 'animal_in_need',
    'description': 'Injured near the road.',
    'user_species': 'Philippine Eagle',
    'severity': null,
    'possible_species': null,
    'possible_invasive': null,
    'place_name': 'Lusod, Kabayan, Benguet',
    'author_id': 'author-1',
    'author_name': 'spotter_one',
    'author_avatar_path': avatar,
    'photo_paths': photos ?? ['$id/photo.webp'],
    'like_count': 4,
    'liked_by_me': false,
    'comment_count': 1,
    'created_at': '2026-11-12T08:00:00+00:00',
    'feed_at': '2026-11-12T09:30:00+00:00',
    ...?more,
  };

  http.Response response(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    request: requests.last,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    requests = [];
    feedRows = [];
    commentRows = [];
    insertedComment = null;
    unsignable = {};
    failLikes = null;
    client = SupabaseClient(
      'https://feed-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.startsWith('/auth/')) {
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
          return response({
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
          });
        }
        if (path.endsWith('/rpc/community_feed')) return response(feedRows);
        if (path == '/rest/v1/report_likes') {
          if (failLikes != null) return response({'message': 'denied'}, 403);
          return http.Response('', 204, request: request);
        }
        if (path == '/rest/v1/report_comments') {
          if (request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            insertedComment = {
              'id': 'comment-new',
              'user_id': body['user_id'],
              'body': body['body'],
              'created_at': '2026-11-12T10:00:00Z',
              'profiles': {'username': 'me', 'avatar_path': 'preset:panda'},
            };
            return response(insertedComment);
          }
          return response(commentRows);
        }
        if (path.contains('/object/sign/')) {
          final object = path.split('/object/sign/').last;
          if (unsignable.any(object.endsWith)) {
            return response({'message': 'not found'}, 404);
          }
          return response({
            'signedURL': '/object/sign/$object?token=test-only',
          });
        }
        throw StateError('Unexpected request: ${request.method} $path');
      }),
    );
    service = SupabaseFeedService(client);
  });
  tearDown(() => client.dispose());

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-only',
    );
    requests.clear();
  }

  Map<String, dynamic> body(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  test('requires authentication before any request', () async {
    await expectLater(service.fetchPage(), throwsA(isA<AuthException>()));
    await expectLater(service.fetchPost('r'), throwsA(isA<AuthException>()));
    await expectLater(service.like('r'), throwsA(isA<AuthException>()));
    await expectLater(service.unlike('r'), throwsA(isA<AuthException>()));
    await expectLater(
      service.fetchComments('r'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      service.addComment('r', 'hi'),
      throwsA(isA<AuthException>()),
    );
    expect(requests, isEmpty);
  });

  test('signed-out service has an empty feed and no write access', () async {
    const signedOut = SignedOutFeedService();
    expect(await signedOut.fetchPage(), isEmpty);
    expect(await signedOut.fetchPost('r'), isNull);
    expect(await signedOut.fetchComments('r'), isEmpty);
    await expectLater(signedOut.like('r'), throwsA(isA<AuthException>()));
    await expectLater(signedOut.unlike('r'), throwsA(isA<AuthException>()));
    await expectLater(
      signedOut.addComment('r', 'hi'),
      throwsA(isA<AuthException>()),
    );
  });

  group('fetchPage', () {
    test('asks for the first page and maps rows with signed photos', () async {
      await signIn();
      feedRows = [
        feedRow('r1', photos: ['r1/photo.webp', 'r1/second.webp']),
      ];
      final posts = await service.fetchPage();

      final rpc = requests.firstWhere(
        (r) => r.url.path.endsWith('/rpc/community_feed'),
      );
      expect(body(rpc), {
        'p_before_at': null,
        'p_before_id': null,
        'p_limit': FeedService.pageSize,
      });
      final post = posts.single;
      expect(post.id, 'r1');
      expect(post.title, 'Philippine Eagle');
      expect(post.likeCount, 4);
      expect(post.photoPaths, ['r1/photo.webp', 'r1/second.webp']);
      expect(post.photoUrls, hasLength(2));
      expect(post.photoUrls.first, contains('/object/sign/report-images/'));
      expect(post.photoUrls.first, contains('r1/photo.webp'));
      // Photos are read from the private bucket and expire after one hour.
      final signing = requests.where((r) => r.url.path.contains('/sign/'));
      expect(signing, hasLength(2));
      expect(body(signing.first)['expiresIn'], 3600);
    });

    test('pages with the time and id of the last post', () async {
      await signIn();
      feedRows = [];
      final last = FeedPost.fromJson(feedRow('r9'));
      await service.fetchPage(before: last);
      final rpc = requests.firstWhere(
        (r) => r.url.path.endsWith('/rpc/community_feed'),
      );
      expect(body(rpc)['p_before_at'], '2026-11-12T09:30:00.000Z');
      expect(body(rpc)['p_before_id'], 'r9');
    });

    test('uses a preset avatar as an asset, with nothing to sign', () async {
      await signIn();
      feedRows = [feedRow('r1', avatar: 'preset:bunny', photos: [])];
      final post = (await service.fetchPage()).single;
      expect(post.authorAvatarAsset, AppAssets.avatarBunny);
      expect(post.authorAvatarUrl, isNull);
      expect(requests.where((r) => r.url.path.contains('/sign/')), isEmpty);
    });

    test('signs an uploaded avatar once for all of an author posts', () async {
      await signIn();
      feedRows = [
        feedRow('r1', avatar: 'author-1/me.webp', photos: []),
        feedRow('r2', avatar: 'author-1/me.webp', photos: []),
      ];
      final posts = await service.fetchPage();
      expect(posts.map((p) => p.authorAvatarUrl), everyElement(isNotNull));
      expect(posts.first.authorAvatarUrl, contains('/object/sign/avatars/'));
      expect(
        requests.where((r) => r.url.path.contains('/object/sign/avatars/')),
        hasLength(1),
      );
    });

    test('an author without an avatar has neither asset nor URL', () async {
      await signIn();
      feedRows = [feedRow('r1', avatar: null, photos: [])];
      final post = (await service.fetchPage()).single;
      expect(post.authorAvatarAsset, isNull);
      expect(post.authorAvatarUrl, isNull);
    });

    test('a photo that cannot be signed is left out, not fatal', () async {
      await signIn();
      unsignable = {'r1/broken.webp'};
      feedRows = [
        feedRow('r1', photos: ['r1/broken.webp', 'r1/ok.webp']),
      ];
      final post = (await service.fetchPage()).single;
      expect(post.photoPaths, hasLength(2));
      expect(post.photoUrls.single, contains('r1/ok.webp'));
    });
  });

  test('fetchPost asks the RPC for one report', () async {
    await signIn();
    feedRows = [feedRow('r5', photos: [])];
    final post = await service.fetchPost('r5');
    expect(post!.id, 'r5');
    final rpc = requests.firstWhere(
      (r) => r.url.path.endsWith('/rpc/community_feed'),
    );
    expect(body(rpc)['p_report_id'], 'r5');
    expect(body(rpc)['p_limit'], 1);

    feedRows = [];
    expect(await service.fetchPost('gone'), isNull);
  });

  group('likes', () {
    test('like inserts the signed-in user and ignores duplicates', () async {
      await signIn();
      await service.like('r1');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.queryParameters['on_conflict'], 'report_id,user_id');
      expect(request.headers['Prefer'], contains('ignore-duplicates'));
      expect(body(request), {'report_id': 'r1', 'user_id': 'user-a'});
    });

    test('unlike deletes only the signed-in user like', () async {
      await signIn();
      await service.unlike('r1');
      final request = requests.single;
      expect(request.method, 'DELETE');
      expect(request.url.queryParameters['report_id'], 'eq.r1');
      expect(request.url.queryParameters['user_id'], 'eq.user-a');
    });

    test('a refused like throws so the ViewModel can roll back', () async {
      await signIn();
      failLikes = true;
      await expectLater(service.like('r1'), throwsA(isA<PostgrestException>()));
    });
  });

  group('comments', () {
    test('lists the newest first from report_comments with authors', () async {
      await signIn();
      commentRows = [
        {
          'id': 'c2',
          'user_id': 'u2',
          'body': 'Second',
          'created_at': '2026-11-12T09:30:00Z',
          'profiles': {'username': 'bird_notes', 'avatar_path': 'preset:bunny'},
        },
        {
          'id': 'c1',
          'user_id': 'u1',
          'body': 'First',
          'created_at': '2026-11-12T09:00:00Z',
          'profiles': {'full_name': 'Trail Walker', 'avatar_path': 'u1/a.webp'},
        },
      ];
      final comments = await service.fetchComments('r1');

      final request = requests.firstWhere(
        (r) => r.url.path == '/rest/v1/report_comments',
      );
      final query = request.url.queryParameters;
      expect(query['report_id'], 'eq.r1');
      expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(query['limit'], '${FeedService.commentLimit}');
      expect(query['select'], contains('profiles('));
      expect(comments.map((c) => c.text), ['Second', 'First']);
      expect(comments.first.authorName, 'bird_notes');
      expect(comments.first.authorAvatarAsset, AppAssets.avatarBunny);
      expect(comments.last.authorName, 'Trail Walker');
      expect(comments.last.authorAvatarUrl, contains('/object/sign/avatars/'));
    });

    test('adds a trimmed comment as the signed-in user', () async {
      await signIn();
      final comment = await service.addComment('r1', '  Lovely bird  ');
      final request = requests.firstWhere((r) => r.method == 'POST');
      expect(body(request), {
        'report_id': 'r1',
        'user_id': 'user-a',
        'body': 'Lovely bird',
      });
      expect(comment.id, 'comment-new');
      expect(comment.text, 'Lovely bird');
      expect(comment.authorName, 'me');
      expect(comment.authorAvatarAsset, AppAssets.avatarPanda);
      expect(insertedComment, isNotNull);
    });

    test('refuses empty and over-long comments without a request', () async {
      await signIn();
      await expectLater(
        service.addComment('r1', '   '),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        service.addComment('r1', 'x' * (PostComment.maxLength + 1)),
        throwsA(isA<FormatException>()),
      );
      expect(requests, isEmpty);
      await service.addComment('r1', 'x' * PostComment.maxLength);
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    });
  });
}
