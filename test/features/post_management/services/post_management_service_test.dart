import 'dart:convert';

import 'package:faunawatch/features/post_management/services/post_management_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabasePostManagementService service;
  late List<http.Request> requests;

  // What the pretend server answers.
  late Map<String, Object?> rpcError;
  late List<Map<String, Object?>> imageRows;
  late List<Map<String, Object?>> listedFiles;
  late List<Map<String, Object?>> deletedRows;
  late bool removeFails;

  setUp(() {
    requests = [];
    rpcError = {};
    imageRows = [
      {'storage_path': 'post-1/photo-1.webp'},
      {'storage_path': 'post-1/photo-2.webp'},
    ];
    listedFiles = [
      {'name': 'photo-1.webp', 'id': 'f1'},
      // Left behind by a failed photo edit.
      {'name': 'edit-9.webp', 'id': 'f9'},
      // A folder, not a file.
      {'name': 'nested', 'id': null},
    ];
    deletedRows = [
      {'id': 'post-1'},
    ];
    removeFails = false;
    client = SupabaseClient(
      'https://posts-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object? body;
        var status = 200;
        if (path == '/rest/v1/rpc/set_my_report_hidden') {
          if (rpcError.isNotEmpty) {
            status = 400;
            body = rpcError;
          }
        } else if (path == '/rest/v1/report_images') {
          body = imageRows;
        } else if (path == '/storage/v1/object/list/report-images') {
          body = listedFiles;
        } else if (path == '/storage/v1/object/report-images') {
          if (removeFails) {
            status = 500;
            body = {'message': 'storage down', 'statusCode': '500'};
          } else {
            body = [];
          }
        } else if (path == '/rest/v1/reports' && request.method == 'DELETE') {
          body = deletedRows;
        } else {
          throw StateError('Unexpected request ${request.method} $path');
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    service = SupabasePostManagementService(client);
  });
  tearDown(() => client.dispose());

  group('setHidden', () {
    test('calls the database function with the post and the choice', () async {
      await service.setHidden('post-1', hidden: true);
      expect(jsonDecode(requests.single.body), {
        'p_report_id': 'post-1',
        'p_hidden': true,
      });
    });

    test('turns database errors into failures the user can read', () async {
      Future<PostActionFailure> failureFor(String message) async {
        rpcError = {'code': 'FW409', 'message': message};
        try {
          await service.setHidden('post-1', hidden: true);
        } on PostActionException catch (error) {
          return error.failure;
        }
        fail('No error for $message');
      }

      expect(await failureFor('report_not_found'), PostActionFailure.notFound);
      expect(
        await failureFor('report_not_public'),
        PostActionFailure.notPublic,
      );
      expect(await failureFor('anything else'), PostActionFailure.unknown);
    });
  });

  group('delete', () {
    test('removes every photo file first, then the post', () async {
      await service.delete('post-1');
      final steps = [
        for (final request in requests) '${request.method} ${request.url.path}',
      ];
      expect(steps, [
        'GET /rest/v1/report_images',
        'POST /storage/v1/object/list/report-images',
        'DELETE /storage/v1/object/report-images',
        'DELETE /rest/v1/reports',
      ]);
      final removed = jsonDecode(requests[2].body)['prefixes'] as List;
      expect(
        removed,
        unorderedEquals([
          'post-1/photo-1.webp',
          'post-1/photo-2.webp',
          'post-1/edit-9.webp',
        ]),
      );
      expect(requests.last.url.queryParameters['id'], 'eq.post-1');
    });

    test('a post without photos only deletes the post', () async {
      imageRows = [];
      listedFiles = [];
      await service.delete('post-1');
      expect(requests.map((request) => request.url.path), [
        '/rest/v1/report_images',
        '/storage/v1/object/list/report-images',
        '/rest/v1/reports',
      ]);
    });

    test('when the photos cannot be removed, the post is kept', () async {
      removeFails = true;
      await expectLater(
        service.delete('post-1'),
        throwsA(
          isA<PostActionException>().having(
            (error) => error.failure,
            'failure',
            PostActionFailure.unknown,
          ),
        ),
      );
      expect(
        requests.where((request) => request.url.path == '/rest/v1/reports'),
        isEmpty,
      );
    });

    test('nothing deleted means the post is gone or not the user\'s', () async {
      deletedRows = [];
      await expectLater(
        service.delete('post-1'),
        throwsA(
          isA<PostActionException>().having(
            (error) => error.failure,
            'failure',
            PostActionFailure.notFound,
          ),
        ),
      );
    });
  });
}
