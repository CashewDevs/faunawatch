import 'dart:convert';

import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/app_release_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GitHubAppReleaseService', () {
    test('asks GitHub for the latest release and reads it', () async {
      late http.Request sent;
      final service = GitHubAppReleaseService(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.0.1+3',
              'html_url': 'https://github.com/CashewDevs/faunawatch/releases/1',
              'body': 'Fixes',
              'assets': <Object>[],
            }),
            200,
          );
        }),
      );

      final release = await service.fetchLatest();

      expect(sent.method, 'GET');
      expect(sent.url, GitHubAppReleaseService.latestReleaseUrl);
      expect(sent.headers['Accept'], 'application/vnd.github+json');
      expect(release?.version, const AppVersion(1, 0, 1, build: 3));
      expect(release?.notes, 'Fixes');
    });

    test('returns null when nothing has been released yet (404)', () async {
      final service = GitHubAppReleaseService(
        MockClient((_) async => http.Response('{"message":"Not Found"}', 404)),
      );

      expect(await service.fetchLatest(), isNull);
    });

    test('throws AppReleaseException for other error answers', () async {
      final service = GitHubAppReleaseService(
        MockClient((_) async => http.Response('rate limited', 403)),
      );

      expect(service.fetchLatest(), throwsA(isA<AppReleaseException>()));
    });

    test('throws AppReleaseException when offline', () async {
      final service = GitHubAppReleaseService(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      expect(service.fetchLatest(), throwsA(isA<AppReleaseException>()));
    });

    test('throws AppReleaseException for an unreadable answer', () async {
      for (final body in ['not json', '[]', '{"tag_name":"nightly"}']) {
        final service = GitHubAppReleaseService(
          MockClient((_) async => http.Response(body, 200)),
        );

        await expectLater(
          service.fetchLatest(),
          throwsA(isA<AppReleaseException>()),
          reason: body,
        );
      }
    });
  });
}
