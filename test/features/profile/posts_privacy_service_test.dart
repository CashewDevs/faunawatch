import 'dart:convert';

import 'package:faunawatch/features/profile/services/posts_privacy_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabasePostsPrivacyService service;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> profiles;
  Object? rpcResult;

  setUp(() {
    requests = [];
    profiles = [];
    rpcResult = true;
    client = SupabaseClient(
      'https://posts-privacy-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object? body;
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
        } else if (path == '/rest/v1/rpc/set_posts_private') {
          body = rpcResult;
        } else {
          throw StateError('Unexpected request path: $path');
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    service = SupabasePostsPrivacyService(client);
  });
  tearDown(() => client.dispose());

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'me@example.com',
      password: 'test-password',
    );
    requests.clear();
  }

  test('signed out never contacts the server', () async {
    await expectLater(service.load(), throwsA(isA<AuthException>()));
    await expectLater(service.save(true), throwsA(isA<AuthException>()));
    expect(requests, isEmpty);
  });

  test('reads only the own posts_private column', () async {
    await signIn();
    profiles = [
      {'posts_private': true},
    ];
    expect(await service.load(), isTrue);
    final query = requests.single.url.queryParameters;
    expect(query['select'], 'posts_private');
    expect(query['id'], 'eq.me');

    profiles = [];
    expect(await service.load(), isFalse);
  });

  test('saves through set_posts_private, not a profile update', () async {
    await signIn();
    expect(await service.save(true), isTrue);
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/rpc/set_posts_private');
    expect(jsonDecode(request.body), {'p_private': true});

    rpcResult = false;
    expect(await service.save(false), isFalse);
  });

  test('the signed-out service saves nothing', () async {
    const signedOut = SignedOutPostsPrivacyService();
    expect(await signedOut.load(), isFalse);
    await expectLater(signedOut.save(true), throwsA(isA<AuthException>()));
  });
}
