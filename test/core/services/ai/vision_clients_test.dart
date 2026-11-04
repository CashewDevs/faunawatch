import 'dart:convert';
import 'dart:typed_data';

import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/core/services/ai/gemini_vision_client.dart';
import 'package:faunawatch/core/services/ai/openai_compatible_vision_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _key = 'secret-test-key';
final _jpeg = Uint8List.fromList([1, 2, 3]);

Future<String> _describe(AiVisionClient client) => client.describeImage(
  apiKey: _key,
  model: 'test-model',
  imageBytes: _jpeg,
  mimeType: 'image/jpeg',
  instructions: 'Identify it.',
);

Matcher _failsWith(AiVisionFailure failure) => throwsA(
  isA<AiVisionException>()
      .having((e) => e.failure, 'failure', failure)
      .having((e) => e.toString(), 'message', isNot(contains(_key))),
);

void main() {
  group('GeminiVisionClient', () {
    test('sends the key in a header and the photo inline', () async {
      late http.Request sent;
      final client = GeminiVisionClient(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"a":'},
                      {'text': '1}'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(await _describe(client), '{"a":1}');
      expect(sent.url.host, 'generativelanguage.googleapis.com');
      expect(sent.url.path, '/v1beta/models/test-model:generateContent');
      expect(sent.url.toString(), isNot(contains(_key)));
      expect(sent.headers['x-goog-api-key'], _key);
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      final parts = body['contents'][0]['parts'] as List;
      expect(parts[0]['text'], 'Identify it.');
      expect(parts[1]['inline_data']['mime_type'], 'image/jpeg');
      expect(parts[1]['inline_data']['data'], base64Encode(_jpeg));
      expect(body['generationConfig']['responseMimeType'], 'application/json');
    });

    test('maps provider errors without exposing the key', () async {
      Future<void> expectStatus(
        int status,
        AiVisionFailure failure, {
        String body = '{}',
      }) async {
        final client = GeminiVisionClient(
          MockClient((_) async => http.Response(body, status)),
        );
        await expectLater(_describe(client), _failsWith(failure));
      }

      await expectStatus(
        400,
        AiVisionFailure.invalidKey,
        body: '{"error":{"details":[{"reason":"API_KEY_INVALID"}]}}',
      );
      await expectStatus(400, AiVisionFailure.badResponse);
      await expectStatus(403, AiVisionFailure.invalidKey);
      await expectStatus(429, AiVisionFailure.rateLimited);
      await expectStatus(503, AiVisionFailure.unavailable);
    });

    test('a blocked or empty reply is a bad response', () async {
      final client = GeminiVisionClient(
        MockClient(
          (_) async =>
              http.Response('{"promptFeedback":{"blockReason":"X"}}', 200),
        ),
      );
      await expectLater(
        _describe(client),
        _failsWith(AiVisionFailure.badResponse),
      );
    });

    test('a dropped connection is a network failure', () async {
      final client = GeminiVisionClient(
        MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(_describe(client), _failsWith(AiVisionFailure.network));
    });
  });

  group('OpenAiCompatibleVisionClient', () {
    http.Response reply(String content) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content},
          },
        ],
      }),
      200,
    );

    test('Groq sends a bearer key and an image_url data URI', () async {
      late http.Request sent;
      final client = OpenAiCompatibleVisionClient.groq(
        MockClient((request) async {
          sent = request;
          return reply('{"ok":true}');
        }),
      );

      expect(await _describe(client), '{"ok":true}');
      expect(sent.url.host, 'api.groq.com');
      expect(sent.url.path, '/openai/v1/chat/completions');
      expect(sent.headers['authorization'], 'Bearer $_key');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], 'test-model');
      final content = body['messages'][0]['content'] as List;
      expect(content[0], {'type': 'text', 'text': 'Identify it.'});
      expect(
        content[1]['image_url']['url'],
        'data:image/jpeg;base64,${base64Encode(_jpeg)}',
      );
    });

    test('OpenRouter uses its own host, model and title header', () async {
      late http.Request sent;
      final client = OpenAiCompatibleVisionClient.openRouter(
        MockClient((request) async {
          sent = request;
          return reply('{}');
        }),
      );

      await _describe(client);
      expect(sent.url.host, 'openrouter.ai');
      expect(sent.url.path, '/api/v1/chat/completions');
      expect(sent.headers['X-Title'], 'FaunaWatch');
      expect(
        (jsonDecode(sent.body) as Map<String, dynamic>)['model'],
        'test-model',
      );
    });

    test('maps provider errors without exposing the key', () async {
      Future<void> expectStatus(int status, AiVisionFailure failure) async {
        final client = OpenAiCompatibleVisionClient.groq(
          MockClient((_) async => http.Response('{}', status)),
        );
        await expectLater(_describe(client), _failsWith(failure));
      }

      await expectStatus(401, AiVisionFailure.invalidKey);
      await expectStatus(404, AiVisionFailure.unavailable);
      await expectStatus(402, AiVisionFailure.rateLimited);
      await expectStatus(429, AiVisionFailure.rateLimited);
      await expectStatus(500, AiVisionFailure.unavailable);
      await expectStatus(400, AiVisionFailure.badResponse);
    });

    test('a reply without text is a bad response', () async {
      final client = OpenAiCompatibleVisionClient.openRouter(
        MockClient((_) async => http.Response('{"choices": []}', 200)),
      );
      await expectLater(
        _describe(client),
        _failsWith(AiVisionFailure.badResponse),
      );
    });
  });

  group('listModels', () {
    test('Gemini keeps photo-capable chat models, newest first', () async {
      late http.Request sent;
      final client = GeminiVisionClient(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-3.5-flash',
                  'displayName': 'Gemini 3.5 Flash',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/gemini-3.6-flash',
                  'displayName': 'Gemini 3.6 Flash',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/gemini-embedding-001',
                  'supportedGenerationMethods': ['embedContent'],
                },
                {
                  'name': 'models/gemini-3.6-flash-tts',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/imagen-4',
                  'supportedGenerationMethods': ['predict'],
                },
              ],
            }),
            200,
          );
        }),
      );

      final models = await client.listModels(apiKey: _key);

      expect(models.map((m) => m.id), ['gemini-3.6-flash', 'gemini-3.5-flash']);
      expect(models.first.name, 'Gemini 3.6 Flash');
      expect(sent.method, 'GET');
      expect(sent.url.path, '/v1beta/models');
      expect(sent.url.toString(), isNot(contains(_key)));
      expect(sent.headers['x-goog-api-key'], _key);
    });

    test('Gemini follows the next page', () async {
      var calls = 0;
      final client = GeminiVisionClient(
        MockClient((request) async {
          calls++;
          final second = request.url.queryParameters['pageToken'] == 'p2';
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': second ? 'models/gemini-b' : 'models/gemini-a',
                  'supportedGenerationMethods': ['generateContent'],
                },
              ],
              if (!second) 'nextPageToken': 'p2',
            }),
            200,
          );
        }),
      );

      final models = await client.listModels(apiKey: _key);

      expect(calls, 2);
      expect(models.map((m) => m.id), ['gemini-b', 'gemini-a']);
    });

    test('OpenRouter keeps only models that take images', () async {
      late http.Request sent;
      final client = OpenAiCompatibleVisionClient.openRouter(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'text/only',
                  'name': 'Text Only',
                  'architecture': {
                    'input_modalities': ['text'],
                  },
                },
                {
                  'id': 'google/gemini-3.6-flash',
                  'name': 'Google: Gemini 3.6 Flash',
                  'architecture': {
                    'input_modalities': ['text', 'image'],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final models = await client.listModels(apiKey: _key);

      expect(models.map((m) => m.id), ['google/gemini-3.6-flash']);
      expect(models.single.name, 'Google: Gemini 3.6 Flash');
      expect(sent.url.toString(), 'https://openrouter.ai/api/v1/models');
      expect(sent.headers['authorization'], 'Bearer $_key');
    });

    test('Groq drops inactive and non-chat models', () async {
      final client = OpenAiCompatibleVisionClient.groq(
        MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': [
                {'id': 'qwen/qwen3.8-27b', 'active': true},
                {'id': 'whisper-large-v3', 'active': true},
                {'id': 'old-model', 'active': false},
                {'id': 'meta-llama/llama-guard-4-12b'},
              ],
            }),
            200,
          ),
        ),
      );

      final models = await client.listModels(apiKey: _key);

      expect(models.map((m) => m.id), ['qwen/qwen3.8-27b']);
    });

    test('a rejected key is reported without exposing it', () async {
      final client = OpenAiCompatibleVisionClient.groq(
        MockClient((_) async => http.Response('{}', 401)),
      );
      await expectLater(
        client.listModels(apiKey: _key),
        _failsWith(AiVisionFailure.invalidKey),
      );
    });

    test('each client has a default model', () {
      final mock = MockClient((_) async => throw UnimplementedError());
      expect(GeminiVisionClient(mock).defaultModel, isNotEmpty);
      expect(
        OpenAiCompatibleVisionClient.groq(mock).defaultModel,
        OpenAiCompatibleVisionClient.groqModel,
      );
      expect(
        OpenAiCompatibleVisionClient.openRouter(mock).defaultModel,
        OpenAiCompatibleVisionClient.openRouterModel,
      );
    });
  });
}
