import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/messages/models/chat_photo.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';

void main() {
  late SupabaseClient client;
  late SupabaseMessagesService service;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> threadRows, messageRows, userRows;
  Map<String, dynamic>? sent;
  bool failSend = false, committed = false, failSigning = false;
  Map<String, dynamic> message({String id = 'message-1', String? path}) => {
    'id': id,
    'sender_id': 'user-a',
    'body': 'Hello',
    'created_at': '2026-11-04T12:00:00Z',
    'image_path': path,
  };
  http.Response response(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    request: requests.last,
    headers: {'content-type': 'application/json'},
  );
  setUp(() {
    requests = [];
    threadRows = [];
    messageRows = [];
    userRows = [];
    sent = null;
    failSend = false;
    committed = false;
    failSigning = false;
    client = SupabaseClient(
      'https://chat-tests.invalid',
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
        if (path.endsWith('/rpc/list_chat_threads')) {
          return response(threadRows);
        }
        if (path.endsWith('/rpc/open_chat')) return response('thread-1');
        if (path.endsWith('/rpc/set_chat_inbox_state')) return response(true);
        if (path.endsWith('/rpc/send_chat_message')) {
          final body = jsonDecode(request.body) as Map;
          sent = message(
            id: body['p_message_id'] as String,
            path: body['p_image_path'] as String?,
          )..['body'] = body['p_body'];
          if (failSend) return response({'message': 'test send failure'}, 400);
          return response(sent);
        }
        if (path == '/rest/v1/chat_messages') {
          if (request.url.queryParameters.containsKey('id')) {
            return response(committed ? sent : null);
          }
          return response(messageRows);
        }
        if (path == '/rest/v1/profiles') return response(userRows);
        if (path.contains('/object/sign/')) {
          return failSigning
              ? response({'message': 'test signing failure'}, 400)
              : response({
                  'signedURL':
                      '/object/sign/chat-images/photo.webp?token=test-only',
                });
        }
        if (path.startsWith('/storage/')) {
          return response({'Key': 'test-upload'});
        }
        throw StateError('Unexpected request: ${request.method} $path');
      }),
    );
    service = SupabaseMessagesService(client);
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
      service.fetchMessageThreads(),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      service.searchUsers('Alice'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      service.sendMessage(threadId: 't', text: 'hello'),
      throwsA(isA<AuthException>()),
    );
    expect(requests, isEmpty);
  });
  test(
    'signed-out service exposes no inbox, subscriptions, or send access',
    () async {
      const signedOut = SignedOutMessagesService();
      expect(await signedOut.fetchMessageThreads(), isEmpty);
      expect(await signedOut.watchInbox().toList(), isEmpty);
      await expectLater(
        signedOut.fetchChatMessages('t'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        signedOut.sendMessage(threadId: 't', text: 'hello'),
        throwsA(isA<AuthException>()),
      );
      expect(requests, isEmpty);
    },
  );
  test('maps server inbox state and preset avatars', () async {
    await signIn();
    threadRows = [
      {
        'id': 't',
        'other_user_id': 'user-b',
        'sender_name': 'Bob',
        'avatar_path': 'preset:bunny',
        'last_message': 'Photo',
        'last_message_at': '2026-11-04T12:00:00Z',
        'unread_count': 2,
        'is_unread': true,
      },
    ];
    final threads = await service.fetchMessageThreads();
    expect(threads.single.avatarAsset, AppAssets.avatarBunny);
    expect(threads.single.unreadCount, 2);
    expect(threads.single.isUnread, isTrue);
    expect(threads.single.lastMessageAt, DateTime.utc(2026, 11, 4, 12));
    expect(requests.length, 1);
  });
  test(
    'uses observed message id for read state and hides only via RPC',
    () async {
      await signIn();
      await service.markAsRead('t', throughMessageId: 'm');
      await service.markAsUnread('t');
      await service.deleteThread('t');
      final bodies = requests.map((r) => jsonDecode(r.body) as Map).toList();
      expect(bodies[0]['p_read_message_id'], 'm');
      expect(bodies.map((b) => b['p_action']), ['read', 'unread', 'hide']);
      expect(requests.every((r) => r.method == 'POST'), isTrue);
    },
  );
  test('loads ordered pages with a timestamp and id cursor', () async {
    await signIn();
    messageRows = [
      message(id: 'new'),
      message(id: 'old')..['sender_id'] = 'user-b',
    ];
    final rows = await service.fetchChatMessages('t');
    expect(rows.map((m) => m.id), ['old', 'new']);
    expect(rows.first.isUser, isFalse);
    await service.fetchChatMessages('t', before: rows.first);
    final query = requests.last.url.queryParameters;
    expect(query['limit'], '50');
    expect(query['thread_id'], 'eq.t');
    expect(query['or'], contains('id.lt.old'));
    expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
  });
  test('rejects blank, long, and oversized sends before upload', () async {
    await signIn();
    for (final text in ['', 'x' * 4001]) {
      await expectLater(
        service.sendMessage(threadId: 't', text: text),
        throwsFormatException,
      );
    }
    await expectLater(
      service.sendMessage(
        threadId: 't',
        text: '',
        photo: ChatPhoto(Uint8List(ChatPhoto.maxBytes + 1)),
      ),
      throwsFormatException,
    );
    expect(requests, isEmpty);
  });
  test('uploads photo privately, then sends only its storage path', () async {
    await signIn();
    final result = await service.sendMessage(
      threadId: 't',
      text: '  Hello  ',
      photo: ChatPhoto(Uint8List.fromList([1, 2, 3])),
    );
    final upload = requests.first;
    expect(
      upload.url.path,
      startsWith('/storage/v1/object/chat-images/user-a/t/'),
    );
    expect(
      utf8.decode(upload.bodyBytes, allowMalformed: true),
      contains('image/webp'),
    );
    final body = jsonDecode(requests[1].body) as Map;
    expect(body['p_body'], 'Hello');
    expect(body['p_image_path'], startsWith('user-a/t/'));
    expect(body.containsKey('sender_id'), isFalse);
    expect(result.imagePath, body['p_image_path']);
    expect(result.imageUrl, contains('/object/sign/'));
  });
  test('cleans up an unshared upload when sending fails', () async {
    await signIn();
    failSend = true;
    await expectLater(
      service.sendMessage(
        threadId: 't',
        text: '',
        photo: ChatPhoto(Uint8List.fromList([1])),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests.where((r) => r.method == 'DELETE').length, 1);
  });
  test(
    'recovers a committed send after a lost response without deleting photo',
    () async {
      await signIn();
      failSend = true;
      committed = true;
      final result = await service.sendMessage(
        threadId: 't',
        text: 'Hello',
        photo: ChatPhoto(Uint8List.fromList([1])),
      );
      expect(result.id, sent!['id']);
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );
  test('signing failure still returns a successfully sent message', () async {
    await signIn();
    failSigning = true;
    final result = await service.sendMessage(
      threadId: 't',
      text: '',
      photo: ChatPhoto(Uint8List.fromList([1])),
    );
    expect(result.imageUrl, isNull);
    expect(result.imagePath, isNotNull);
  });
  test('search excludes self, limits rows and strips query syntax', () async {
    await signIn();
    expect(await service.searchUsers('a'), isEmpty);
    expect(requests, isEmpty);
    userRows = [
      {'id': 'user-b', 'display_name': 'Bob'},
    ];
    final users = await service.searchUsers('Bo),id.neq.x%');
    expect(users.single.name, 'Bob');
    final query = requests.single.url.queryParameters;
    expect(query['id'], 'neq.user-a');
    expect(query['limit'], '20');
    expect(query['or'], isNot(contains('id.neq')));
  });
  test('opens the unique pair through the checked RPC', () async {
    await signIn();
    final thread = await service.openChat(
      const ChatUser(id: 'user-b', name: 'Bob'),
    );
    expect(thread.id, 'thread-1');
    expect(jsonDecode(requests.single.body), {'p_other_user_id': 'user-b'});
  });
  test(
    'search resolves both preset avatar identifiers and existing asset paths',
    () async {
      await signIn();
      userRows = [
        {'id': 'b', 'display_name': 'Bob', 'avatar_path': 'preset:bunny'},
        {
          'id': 'c',
          'display_name': 'Chris',
          'avatar_path': AppAssets.avatarGrizz,
        },
      ];
      final users = await service.searchUsers('bo');
      expect(users.map((user) => user.avatarAsset), [
        AppAssets.avatarBunny,
        AppAssets.avatarGrizz,
      ]);
      expect(users.every((user) => user.avatarUrl == null), isTrue);
      expect(requests.length, 1);
    },
  );
  test(
    'search signs uploaded avatars through the private avatars bucket',
    () async {
      await signIn();
      userRows = [
        {'id': 'b', 'display_name': 'Bob', 'avatar_path': 'b/photo.webp'},
      ];
      final user = (await service.searchUsers('Bob')).single;
      expect(user.avatarUrl, contains('token=test-only'));
      expect(user.avatarAsset, isNull);
      expect(user.avatarPath, 'b/photo.webp');
      expect(
        requests.last.url.path,
        '/storage/v1/object/sign/avatars/b/photo.webp',
      );
    },
  );
  test('missing or unavailable avatars do not prevent finding users', () async {
    await signIn();
    failSigning = true;
    userRows = [
      {'id': 'b', 'display_name': 'Bob'},
      {'id': 'c', 'display_name': 'Chris', 'avatar_path': 'c/missing.webp'},
      {'id': 'd', 'display_name': 'Dave', 'avatar_path': 'preset:unknown'},
    ];
    final users = await service.searchUsers('bo');
    expect(users.length, 3);
    expect(
      users.every((user) => user.avatarAsset == null && user.avatarUrl == null),
      isTrue,
    );
  });
}
