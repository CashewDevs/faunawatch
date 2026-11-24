import 'dart:convert';
import 'dart:typed_data';

import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/services/post_photo_service.dart';
import 'package:faunawatch/features/post_management/models/edit_post_state.dart';
import 'package:faunawatch/features/post_management/services/edit_post_service.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fauna_lens/ai_fakes.dart';
import '../fake_edit_post_service.dart';

class _FakePhotos implements PostPhotoService {
  final prepared = <String>[];

  @override
  Future<PreparedPostPhoto> prepare(String path) async {
    if (path.contains('huge')) {
      throw const FormatException('Choose a photo of 5 MB or less.');
    }
    prepared.add(path);
    return PreparedPostPhoto(
      bytes: Uint8List.fromList([1, 2, 3]),
      fingerprint: 'fp-$path',
      exif: path.contains('gps') ? {'gps_latitude': 10.3} : const {},
    );
  }
}

void main() {
  late SupabaseClient client;
  late SupabaseEditPostService service;
  late _FakePhotos photos;
  late List<http.Request> requests;
  late Map<String, Object?>? rpcError;
  late List<String> removedByDatabase;

  setUp(() {
    requests = [];
    rpcError = null;
    removedByDatabase = ['post-1/photo-2.webp'];
    photos = _FakePhotos();
    client = SupabaseClient(
      'https://edit-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object? body = {};
        var status = 200;
        if (path.startsWith('/rest/v1/rpc/')) {
          if (rpcError != null) {
            status = 400;
            body = rpcError;
          } else {
            body = path.endsWith('apply_my_report_photo_edit')
                ? removedByDatabase
                : null;
          }
        } else if (path.startsWith('/storage/v1/object/report-images/')) {
          body = {'Key': path};
        } else if (path == '/storage/v1/object/report-images') {
          body = [];
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
    service = SupabaseEditPostService(client, photos);
  });
  tearDown(() => client.dispose());

  List<String> steps() => [
    for (final request in requests) '${request.method} ${request.url.path}',
  ];

  Map<String, dynamic> rpcBody() =>
      jsonDecode(requests.firstWhere((r) => r.url.path.contains('/rpc/')).body);

  test('a caption is saved through the database function', () async {
    await service.updateCaption('post-1', 'New caption');
    expect(steps(), ['POST /rest/v1/rpc/update_my_report_caption']);
    expect(rpcBody(), {
      'p_report_id': 'post-1',
      'p_description': 'New caption',
    });
  });

  test('database errors become messages the user can read', () async {
    Future<EditPostException> errorFor(String message) async {
      rpcError = {'code': 'FW409', 'message': message};
      try {
        await service.updateCaption('post-1', 'x');
      } on EditPostException catch (error) {
        return error;
      }
      fail('No error for $message');
    }

    expect(await errorFor('account_suspended'), EditPostException.suspended);
    expect(await errorFor('report_not_found'), EditPostException.notFound);
    expect(
      await errorFor('report_not_editable'),
      EditPostException.notEditable,
    );
    expect(await errorFor('analysis_required'), EditPostException.failed);
  });

  test('new photos are uploaded, then swapped in at once, then the dropped '
      'files are removed', () async {
    final analysis = sampleIdentification(
      category: ReportCategory.potentiallyDangerousAnimal,
    );
    await service.replacePhotos('post-1', const [
      NewPhoto('/gps.jpg'),
      coverPhoto,
    ], analysis: analysis);

    expect(steps(), [
      startsWith('POST /storage/v1/object/report-images/post-1/edit-'),
      'POST /rest/v1/rpc/apply_my_report_photo_edit',
      'DELETE /storage/v1/object/report-images',
    ]);
    final uploadedPath = requests.first.url.path.split('report-images/').last;
    expect(uploadedPath, matches(RegExp(r'^post-1/edit-\d+-1\.webp$')));

    final body = rpcBody();
    expect(body['p_report_id'], 'post-1');
    expect(body['p_photos'], [
      {
        'storage_path': uploadedPath,
        'size_bytes': 3,
        'fingerprint': 'fp-/gps.jpg',
        'exif': {'gps_latitude': 10.3},
      },
      {'image_id': 'img-1'},
    ]);
    expect(body['p_category'], 'potentially_dangerous_animal');
    expect(body['p_analysis']['report_id'], 'post-1');
    expect(body['p_analysis']['status'], 'completed');

    expect(jsonDecode(requests.last.body)['prefixes'], ['post-1/photo-2.webp']);
  });

  test('keeping the cover sends no analysis or category', () async {
    removedByDatabase = [];
    await service.replacePhotos('post-1', const [coverPhoto]);
    expect(steps(), ['POST /rest/v1/rpc/apply_my_report_photo_edit']);
    expect(rpcBody()['p_analysis'], isNull);
    expect(rpcBody()['p_category'], isNull);
    expect(rpcBody()['p_photos'], [
      {'image_id': 'img-1'},
    ]);
  });

  test(
    'when the database refuses, the uploaded photos are removed again',
    () async {
      rpcError = {'code': 'FW403', 'message': 'account_suspended'};
      await expectLater(
        service.replacePhotos('post-1', const [
          NewPhoto('/a.jpg'),
        ], analysis: sampleIdentification()),
        throwsA(EditPostException.suspended),
      );
      expect(steps().last, 'DELETE /storage/v1/object/report-images');
      final uploaded = requests.first.url.path.split('report-images/').last;
      expect(jsonDecode(requests.last.body)['prefixes'], [uploaded]);
    },
  );

  test('a photo that cannot be prepared stops before any upload', () async {
    await expectLater(
      service.replacePhotos('post-1', const [
        NewPhoto('/huge.jpg'),
      ], analysis: sampleIdentification()),
      throwsA(
        isA<EditPostException>().having(
          (error) => error.message,
          'message',
          'Choose a photo of 5 MB or less.',
        ),
      ),
    );
    expect(requests, isEmpty);
  });

  test('loads the post with its photos in order and signed links', () async {
    final loadClient = SupabaseClient(
      'https://edit-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        Object body;
        if (path.startsWith('/auth/')) {
          body = _session();
        } else if (path == '/rest/v1/reports') {
          expect(request.url.queryParameters['user_id'], 'eq.user-a');
          body = {
            'id': 'post-1',
            'status': 'approved',
            'category': 'animal_in_need',
            'description': ' Caption ',
            'report_images': [
              {'id': 'img-1', 'storage_path': 'post-1/photo-1.webp'},
              {'id': 'img-2', 'storage_path': 'post-1/photo-2.webp'},
            ],
          };
        } else if (path.contains('/object/sign/')) {
          body = {'signedURL': '/object/sign/x?token=test-only'};
        } else {
          throw StateError('Unexpected request $path');
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(loadClient.dispose);
    await loadClient.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-only',
    );
    final post = await SupabaseEditPostService(
      loadClient,
      photos,
    ).load('post-1');
    expect(post!.status, ReportStatus.approved);
    expect(post.category, ReportCategory.animalInNeed);
    expect(post.description, 'Caption');
    expect(post.photos.map((photo) => photo.imageId), ['img-1', 'img-2']);
    expect(post.photos.first.url, contains('token=test-only'));
  });
}

Map<String, Object?> _session() {
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
  return {
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
}
