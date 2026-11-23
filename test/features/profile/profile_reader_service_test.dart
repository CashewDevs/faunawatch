import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/profile/services/profile_reader_service.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseProfileReaderService service;
  late List<Map<String, Object?>> rows;
  late List<Uri> requests;
  late List<Map<String, dynamic>> updates;
  late bool rejectBioColumn, rejectPostsPrivateColumn, rejectProfileTagColumn;
  setUp(() async {
    rows = [];
    requests = [];
    updates = [];
    rejectBioColumn = false;
    rejectPostsPrivateColumn = false;
    rejectProfileTagColumn = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final url = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      final select = request.uri.queryParameters['select'] ?? '';
      // Like Postgres, report the first missing column in the select list.
      final missing = request.method != 'GET'
          ? null
          : rejectBioColumn && select.contains('bio')
          ? 'bio'
          : rejectPostsPrivateColumn && select.contains('posts_private')
          ? 'posts_private'
          : rejectProfileTagColumn && select.contains('profile_tag')
          ? 'profile_tag'
          : null;
      if (missing != null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(
          jsonEncode({
            'code': '42703',
            'details': null,
            'hint': null,
            'message': 'column profiles.$missing does not exist',
          }),
        );
        await request.response.close();
        return;
      }
      if (request.method == 'PATCH') {
        updates.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
      }
      if (request.uri.path.startsWith('/auth/')) {
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
        await request.response.close();
        return;
      }
      request.response.write(
        jsonEncode(
          request.uri.path.contains('/storage/')
              ? {'signedURL': '/object/sign/avatars/user/photo.jpg?token=test'}
              : rows,
        ),
      );
      await request.response.close();
    });
    client = SupabaseClient(url, 'test-anon-key');
    service = SupabaseProfileReaderService(client);
  });

  test(
    'loads a saved bio and trims whitespace, defaulting null to empty',
    () async {
      rows = [
        {'display_name': 'Tester', 'bio': '  Forest bird spotter  '},
      ];
      var profile = await service.loadProfile('user-a');
      expect(profile.bio, 'Forest bird spotter');

      rows = [
        {'display_name': 'Tester', 'bio': null},
      ];
      profile = await service.loadProfile('user-a');
      expect(profile.bio, isEmpty);
    },
  );

  test('reads confirmed profile tags and hides unknown values', () async {
    rows = [
      {'display_name': 'Tester', 'profile_tag': 'dog_lover'},
    ];
    expect(
      (await service.loadProfile('user-a')).profileTag,
      ProfileTag.dogLover,
    );
    rows = [
      {'profile_tag': 'unknown'},
    ];
    expect((await service.loadProfile('user-a')).profileTag, isNull);
  });

  test(
    'older databases still load profiles without the tag migration',
    () async {
      rejectProfileTagColumn = true;
      rows = [
        {'display_name': 'Tester', 'bio': 'Bird watcher'},
      ];
      final profile = await service.loadProfile('user-a');
      expect(profile.bio, 'Bird watcher');
      expect(profile.profileTag, isNull);
      expect(requests, hasLength(2));
      expect(
        requests.last.queryParameters['select'],
        isNot(contains('profile_tag')),
      );
    },
  );

  test(
    'falls back to legacy columns when profiles.bio migration is not applied',
    () async {
      rejectBioColumn = true;
      rows = [
        {'display_name': 'Tester', 'avatar_path': AppAssets.avatarBunny},
      ];
      final profile = await service.loadProfile('user-a');
      expect(profile.username, 'Tester');
      expect(profile.presetAvatar, AppAssets.avatarBunny);
      expect(profile.bio, isEmpty);
      expect(requests.length, 2);
      expect(requests.first.queryParameters['select'], contains('bio'));
      expect(requests.last.queryParameters['select'], isNot(contains('bio')));
    },
  );

  test('reads whether the account turned on Private posts', () async {
    rows = [
      {'display_name': 'Tester', 'posts_private': true},
    ];
    expect((await service.loadProfile('user-a')).postsPrivate, isTrue);
    expect(
      requests.single.queryParameters['select'],
      contains('posts_private'),
    );

    rows = [
      {'display_name': 'Tester', 'posts_private': false},
    ];
    expect((await service.loadProfile('user-a')).postsPrivate, isFalse);
  });

  test(
    'reads profiles when the Private posts migration is not applied',
    () async {
      rejectPostsPrivateColumn = true;
      rows = [
        {'display_name': 'Tester', 'bio': 'Bird watcher'},
      ];
      final profile = await service.loadProfile('user-a');
      expect(profile.bio, 'Bird watcher');
      expect(profile.postsPrivate, isFalse);
      expect(requests.length, 2);
      expect(
        requests.last.queryParameters['select'],
        allOf(contains('bio'), isNot(contains('posts_private'))),
      );
    },
  );

  test('reads profiles missing both newer columns', () async {
    rejectBioColumn = true;
    rejectPostsPrivateColumn = true;
    rows = [
      {'display_name': 'Tester'},
    ];
    final profile = await service.loadProfile('user-a');
    expect(profile.username, 'Tester');
    expect(requests.length, 3);
    expect(
      requests.last.queryParameters['select'],
      allOf(isNot(contains('bio')), isNot(contains('posts_private'))),
    );
  });

  test(
    'saves display name and bio to the authenticated user and validates input',
    () async {
      final writer = SupabaseProfileService(client);
      expect(
        await writer.saveProfile(username: 'Tester', bio: 'Bird watcher'),
        isFalse,
      );
      expect(requests, isEmpty);

      await client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'test-password',
      );
      requests.clear();
      rows = [
        {'id': 'user-a'},
      ];

      expect(
        await writer.saveProfile(
          username: '  Tester  ',
          bio: '  Bird watcher  ',
        ),
        isTrue,
      );
      expect(updates.last, {'display_name': 'Tester', 'bio': 'Bird watcher'});
      expect(requests.last.queryParameters['id'], 'eq.user-a');

      // Clearing bio writes null so existing bio can be removed cleanly.
      expect(await writer.saveProfile(username: 'Tester', bio: '   '), isTrue);
      expect(updates.last, {'display_name': 'Tester', 'bio': null});

      // Rejects blank username or bio exceeding 50 characters without a request.
      final countBeforeInvalid = requests.length;
      expect(await writer.saveProfile(username: '   ', bio: 'ok'), isFalse);
      expect(
        await writer.saveProfile(username: 'Tester', bio: 'a' * 51),
        isFalse,
      );
      expect(requests.length, countBeforeInvalid);

      // Returns false when no row was updated.
      rows = [];
      expect(
        await writer.saveProfile(username: 'Tester', bio: 'Bird watcher'),
        isFalse,
      );
    },
  );

  test(
    'loads a saved banner preset or ARGB color, with nulls for older profiles',
    () async {
      rows = [
        {'banner_asset': AppAssets.bannerNight, 'banner_color': null},
      ];
      var profile = await service.loadProfile('user-a');
      expect(profile.bannerAsset, AppAssets.bannerNight);
      expect(profile.bannerColorValue, isNull);
      rows = [
        {'banner_asset': null, 'banner_color': 0xFFBCE7B4},
      ];
      profile = await service.loadProfile('user-a');
      expect(profile.bannerAsset, isNull);
      expect(profile.bannerColorValue, 0xFFBCE7B4);
      rows = [{}];
      profile = await service.loadProfile('user-a');
      expect(profile.bannerAsset, isNull);
      expect(profile.bannerColorValue, isNull);
    },
  );

  test(
    'saves banner choices to the authenticated user and clears the other field',
    () async {
      await client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'test-password',
      );
      rows = [
        {'id': 'user-a'},
      ];
      final writer = SupabaseProfileService(client);
      expect(
        await writer.saveProfileBanner(bannerAsset: AppAssets.bannerNight),
        isTrue,
      );
      expect(updates.last, {
        'banner_asset': AppAssets.bannerNight,
        'banner_color': null,
      });
      expect(requests.last.queryParameters['id'], 'eq.user-a');
      expect(await writer.saveProfileBanner(colorValue: 0xFFBCE7B4), isTrue);
      expect(updates.last, {'banner_asset': null, 'banner_color': 0xFFBCE7B4});
      expect(await writer.saveProfileBanner(), isTrue);
      expect(updates.last, {'banner_asset': null, 'banner_color': null});
      rows = [];
      expect(await writer.saveProfileBanner(colorValue: 0xFFBCE7B4), isFalse);
    },
  );

  test('banner save rejects signed-out users and invalid choices', () async {
    final writer = SupabaseProfileService(client);
    expect(
      await writer.saveProfileBanner(bannerAsset: AppAssets.bannerDay),
      isFalse,
    );
    expect(requests, isEmpty);
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-password',
    );
    requests.clear();
    expect(
      await writer.saveProfileBanner(
        bannerAsset: AppAssets.bannerDay,
        colorValue: 1,
      ),
      isFalse,
    );
    expect(await writer.saveProfileBanner(bannerAsset: 'unknown'), isFalse);
    expect(await writer.saveProfileBanner(colorValue: -1), isFalse);
    expect(await writer.saveProfileBanner(colorValue: 0x100000000), isFalse);
    expect(requests, isEmpty);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'reads legacy display name and asset avatar for the requested user',
    () async {
      rows = [
        {
          'display_name': 'Tester',
          'username': null,
          'full_name': null,
          'avatar_path': AppAssets.avatarBunny,
        },
      ];
      final profile = await service.loadProfile('user-a');
      expect(profile.username, 'Tester');
      expect(profile.presetAvatar, AppAssets.avatarBunny);
      expect(profile.bio, isEmpty);
      expect(requests.single.queryParameters['id'], 'eq.user-a');
    },
  );

  test('prefers username and resolves preset identifiers', () async {
    rows = [
      {
        'username': 'spotter',
        'full_name': 'Full Name',
        'display_name': 'Legacy',
        'avatar_path': 'preset:bunny',
      },
    ];
    final profile = await service.loadProfile('user-a');
    expect(profile.username, 'spotter');
    expect(profile.presetAvatar, AppAssets.avatarBunny);
  });

  test('uses full name when username is blank', () async {
    rows = [
      {'username': ' ', 'full_name': 'Full Name', 'display_name': 'Legacy'},
    ];
    expect((await service.loadProfile('user-a')).username, 'Full Name');
  });

  test('missing row has no fictional identity or bio', () async {
    final profile = await service.loadProfile('user-a');
    expect(profile.username, isEmpty);
    expect(profile.bio, isEmpty);
  });

  test('uploaded avatar gets a signed URL for the private bucket', () async {
    rows = [
      {'display_name': 'Tester', 'avatar_path': 'user/photo.jpg'},
    ];
    final profile = await service.loadProfile('user-a');
    expect(profile.presetAvatar, isNull);
    expect(profile.avatarUrl, contains('/object/sign/avatars/user/photo.jpg'));
    expect(
      requests.last.path,
      '/storage/v1/object/sign/avatars/user/photo.jpg',
    );
  });
}
