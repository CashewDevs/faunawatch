import 'dart:convert';
import 'dart:io';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:faunawatch/features/profile/services/profile_tag_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseProfileTagService service;
  late List<({String method, Uri uri, Map<String, dynamic> body})> requests;
  late Object activity;
  late List<Map<String, String>> updatedRows;

  setUp(() async {
    requests = [];
    activity = [
      {'approved_reports': 5, 'dog_reports': 3, 'cat_reports': 0},
    ];
    updatedRows = [
      {'id': 'user-a'},
    ];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
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
      } else {
        final raw = await utf8.decoder.bind(request).join();
        final body = raw.isEmpty ? null : jsonDecode(raw);
        requests.add((
          method: request.method,
          uri: request.uri,
          body: body is Map ? Map<String, dynamic>.from(body) : {},
        ));
        request.response.write(
          jsonEncode(request.method == 'PATCH' ? updatedRows : activity),
        );
      }
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');
    service = SupabaseProfileTagService(client, 'user-a');
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  Future<void> signIn() => client.auth.signInWithPassword(
    email: 'test@example.com',
    password: 'test-password',
  );

  test('signed-out or replaced accounts cannot read or write', () async {
    await expectLater(service.fetchActivity(), throwsA(isA<AuthException>()));
    await expectLater(
      service.saveTag(ProfileTag.dogLover),
      throwsA(isA<AuthException>()),
    );
    await signIn();
    final other = SupabaseProfileTagService(client, 'other-account');
    await expectLater(other.fetchActivity(), throwsA(isA<AuthException>()));
    await expectLater(other.saveTag(null), throwsA(isA<AuthException>()));
    expect(requests, isEmpty);
  });

  test(
    'loads aggregate counts without accepting an account parameter',
    () async {
      await signIn();
      final summary = await service.fetchActivity();
      expect(summary.approvedReports, 5);
      expect(summary.suggestions, [ProfileTag.dogLover]);
      expect(requests.single.uri.path, '/rest/v1/rpc/my_profile_tag_activity');
      expect(requests.single.body, isEmpty);
    },
  );

  test(
    'confirmation and removal update only the captured account tag',
    () async {
      await signIn();
      expect(await service.saveTag(ProfileTag.catLover), isTrue);
      expect(requests.single.method, 'PATCH');
      expect(requests.single.uri.queryParameters['id'], 'eq.user-a');
      expect(requests.single.body, {'profile_tag': 'cat_lover'});
      expect(await service.saveTag(null), isTrue);
      expect(requests.last.body, {'profile_tag': null});
      updatedRows = [];
      expect(await service.saveTag(ProfileTag.spotter), isFalse);
    },
  );

  test('malformed summaries fail instead of fabricating suggestions', () async {
    await signIn();
    for (final bad in [
      [],
      [null],
      [
        {'approved_reports': 5, 'dog_reports': 6, 'cat_reports': 0},
      ],
    ]) {
      activity = bad;
      await expectLater(service.fetchActivity(), throwsFormatException);
    }
  });
}
