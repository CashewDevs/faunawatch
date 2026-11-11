import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';

void main() {
  late SupabaseClient client;
  late SupabaseNotificationsService service;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> rows;
  int unreadCount = 0;
  bool failRequests = false;

  Map<String, dynamic> row(String id, {String? readAt}) => {
    'id': id,
    'user_id': 'user-a',
    'type': 'report_comment',
    'title': 'Sam commented on your report',
    'body': 'Nice find',
    'report_id': 'report-1',
    'thread_id': null,
    'actor_id': 'user-b',
    'read_at': readAt,
    'created_at': '2026-11-12T08:30:00+00:00',
  };

  http.Response response(
    Object? body, {
    int status = 200,
    Map<String, String> headers = const {},
  }) => http.Response(
    body == null ? '' : jsonEncode(body),
    status,
    request: requests.last,
    headers: {'content-type': 'application/json', ...headers},
  );

  setUp(() {
    requests = [];
    rows = [];
    unreadCount = 0;
    failRequests = false;
    client = SupabaseClient(
      'https://notifications-tests.invalid',
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
        if (path == '/rest/v1/notifications') {
          if (failRequests) {
            return response({'message': 'test failure'}, status: 400);
          }
          switch (request.method) {
            case 'GET':
              return response(rows);
            case 'HEAD':
              return response(
                null,
                headers: {'content-range': '*/$unreadCount'},
              );
            default:
              return response(null, status: 204);
          }
        }
        throw StateError('Unexpected request: ${request.method} $path');
      }),
    );
    service = SupabaseNotificationsService(client);
  });
  tearDown(() => client.dispose());

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-only',
    );
    requests.clear();
  }

  test('requires authentication before any request', () async {
    await expectLater(
      service.getNotifications(),
      throwsA(isA<AuthException>()),
    );
    await expectLater(service.countUnread(), throwsA(isA<AuthException>()));
    await expectLater(service.markAsRead('n'), throwsA(isA<AuthException>()));
    await expectLater(
      service.deleteNotification('n'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(service.markAllAsRead(), throwsA(isA<AuthException>()));
    expect(() => service.watchNotifications(), throwsA(isA<AuthException>()));
    expect(requests, isEmpty);
  });

  test('signed-out service is empty and rejects changes', () async {
    const signedOut = SignedOutNotificationsService();

    expect(await signedOut.getNotifications(), isEmpty);
    expect(await signedOut.countUnread(), 0);
    expect(await signedOut.watchNotifications().toList(), isEmpty);
    await expectLater(signedOut.markAsRead('n'), throwsA(isA<AuthException>()));
    await expectLater(signedOut.markAllAsRead(), throwsA(isA<AuthException>()));
    expect(requests, isEmpty);
  });

  test('loads the newest page for the signed-in user', () async {
    await signIn();
    rows = [row('n-2'), row('n-1', readAt: '2026-11-12T09:00:00+00:00')];

    final items = await service.getNotifications();

    expect(items.map((item) => item.id), ['n-2', 'n-1']);
    expect(items.first.isUnread, isTrue);
    expect(items.last.isUnread, isFalse);
    expect(items.first.type, NotificationType.comment);
    expect(items.first.timestamp, isEmpty);
    expect(requests, hasLength(1));
    final query = requests.single.url.queryParameters;
    expect(requests.single.method, 'GET');
    expect(query['user_id'], 'eq.user-a');
    expect(query['limit'], '50');
    expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
    expect(query.containsKey('or'), isFalse);
  });

  test('pages older notifications with a timestamp and id cursor', () async {
    await signIn();
    rows = [row('n-9')];
    final before = NotificationItem.fromJson(row('n-5'));

    await service.getNotifications(before: before);

    final query = requests.single.url.queryParameters;
    expect(
      query['or'],
      '(created_at.lt.2026-11-12T08:30:00.000Z,'
      'and(created_at.eq.2026-11-12T08:30:00.000Z,id.lt.n-5))',
    );
  });

  test('counts unread notifications without loading them', () async {
    await signIn();
    unreadCount = 7;

    expect(await service.countUnread(), 7);

    final request = requests.single;
    expect(request.method, 'HEAD');
    expect(request.url.queryParameters['user_id'], 'eq.user-a');
    expect(request.url.queryParameters['read_at'], 'is.null');
  });

  test('marks one notification read by setting only read_at', () async {
    await signIn();

    await service.markAsRead('n-1');

    final request = requests.single;
    expect(request.method, 'PATCH');
    expect(request.url.queryParameters['id'], 'eq.n-1');
    expect(request.url.queryParameters['user_id'], 'eq.user-a');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body.keys, ['read_at']);
    expect(DateTime.parse(body['read_at'] as String).isUtc, isTrue);
  });

  test('marks one notification unread by clearing read_at', () async {
    await signIn();

    await service.markAsUnread('n-1');

    final request = requests.single;
    expect(request.method, 'PATCH');
    expect(request.url.queryParameters['id'], 'eq.n-1');
    expect(jsonDecode(request.body), {'read_at': null});
  });

  test('deletes only the chosen notification of this user', () async {
    await signIn();

    await service.deleteNotification('n-1');

    final request = requests.single;
    expect(request.method, 'DELETE');
    expect(request.url.queryParameters['id'], 'eq.n-1');
    expect(request.url.queryParameters['user_id'], 'eq.user-a');
  });

  test('marks all read by updating only this user\'s unread rows', () async {
    await signIn();

    await service.markAllAsRead();

    final request = requests.single;
    expect(request.method, 'PATCH');
    expect(request.url.queryParameters['user_id'], 'eq.user-a');
    expect(request.url.queryParameters['read_at'], 'is.null');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body.keys, ['read_at']);
    expect(body['read_at'], isNotNull);
  });

  test('server failures reach the caller', () async {
    await signIn();
    failRequests = true;

    await expectLater(
      service.getNotifications(),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      service.markAsRead('n-1'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
