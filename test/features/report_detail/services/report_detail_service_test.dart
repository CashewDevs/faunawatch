import 'dart:convert';

import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabaseReportDetailService service;
  late List<http.Request> requests;
  late Map<String, dynamic> report;
  late Object reviews;
  late bool reviewsFail;

  setUp(() {
    requests = [];
    reviewsFail = false;
    reviews = [];
    report = {
      'id': 'r1',
      'user_id': 'user-a',
      'status': 'declined',
      'category': 'animal_in_need',
      'description': 'A toad.',
      'user_species': null,
      'created_at': '2026-11-17T08:00:00Z',
      'place_name': 'Cebu City',
      'latitude': 10.316789,
      'longitude': 123.891234,
      'report_images': [],
      'ai_analyses': [
        {
          'status': 'completed',
          'possible_species': [
            {'common_name': 'Cane toad', 'confidence': 'high'},
          ],
          'severity': 'low',
          'possible_invasive': true,
          'visual_condition_assessment': 'Healthy.',
          'safety_recommendations': 'Leave it alone.',
          'species_reference': {'common_name': 'Cane toad'},
        },
      ],
    };
    client = SupabaseClient(
      'https://report-detail-tests.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body;
        var status = 200;
        if (request.url.path.startsWith('/auth/')) {
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
          body = {
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
        } else if (request.url.path == '/rest/v1/reports') {
          body = report;
        } else if (request.url.path == '/rest/v1/rpc/my_report_reviews') {
          if (reviewsFail) {
            status = 500;
            body = {'message': 'down'};
          } else {
            body = reviews;
          }
        } else {
          throw StateError('Unexpected request ${request.url.path}');
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    service = SupabaseReportDetailService(client);
  });
  tearDown(() => client.dispose());

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-only',
    );
    requests.clear();
  }

  test('never asks for private notes or the responder briefing', () async {
    await signIn();
    await service.fetchOwnReport('r1');
    final select = requests.first.url.queryParameters['select']!;
    expect(select, isNot(contains('user_notes')));
    expect(select, isNot(contains('responder_briefing')));
    expect(select, contains('safety_recommendations'));
  });

  test('rounds the location and reads the full AI analysis', () async {
    await signIn();
    final own = await service.fetchOwnReport('r1');
    expect(own!.post.approxLatitude, 10.317);
    expect(own.post.approxLongitude, 123.891);
    final ai = own.post.aiAnalysis!;
    expect(ai.species.single.commonName, 'Cane toad');
    expect(ai.severity, SeverityLevel.low);
    expect(ai.possibleInvasive, isTrue);
    expect(ai.invasiveMatchName, 'Cane toad');
    expect(ai.visualCondition, 'Healthy.');
    expect(ai.safetyRecommendations, 'Leave it alone.');
  });

  test('a declined report carries its latest decline reason', () async {
    await signIn();
    reviews = [
      {'decision': 'declined', 'decline_reason': 'duplicate'},
      {'decision': 'approved', 'decline_reason': null},
      {'decision': 'declined', 'decline_reason': 'not_wildlife'},
    ];
    final own = await service.fetchOwnReport('r1');
    expect(own!.status, ReportStatus.declined);
    expect(own.declineReason, DeclineReason.notWildlife);
    final rpc = requests.singleWhere((r) => r.url.path.contains('/rpc/'));
    expect(jsonDecode(rpc.body), {'p_report_id': 'r1'});
  });

  test('a failed reason lookup still loads the report', () async {
    await signIn();
    reviewsFail = true;
    final own = await service.fetchOwnReport('r1');
    expect(own!.status, ReportStatus.declined);
    expect(own.declineReason, isNull);
  });

  test('other statuses do not look up a reason', () async {
    await signIn();
    report['status'] = 'pending';
    final own = await service.fetchOwnReport('r1');
    expect(own!.declineReason, isNull);
    expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
  });

  test('reads the exact own location only for the owner', () async {
    await signIn();
    report = {'latitude': 10.316789, 'longitude': 123.891234};
    final point = await service.fetchOwnLocation('r1');
    expect(point, (latitude: 10.316789, longitude: 123.891234));
    final query = requests.single.url.queryParameters;
    expect(query['select'], 'latitude,longitude');
    expect(query['id'], 'eq.r1');
    expect(query['user_id'], 'eq.user-a');
  });

  test('a missing location is null', () async {
    await signIn();
    report = {'latitude': null, 'longitude': null};
    expect(await service.fetchOwnLocation('r1'), isNull);
    expect(
      await const SignedOutReportDetailService().fetchOwnLocation('r1'),
      isNull,
    );
  });

  test('unknown reasons are ignored', () {
    expect(DeclineReason.fromDb('inaccurate_gps'), DeclineReason.inaccurateGps);
    expect(DeclineReason.fromDb('something_new'), isNull);
    expect(DeclineReason.fromDb(null), isNull);
  });
}
