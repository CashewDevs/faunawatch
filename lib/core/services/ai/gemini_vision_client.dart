import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';

/// Google Gemini through the Generative Language API.
class GeminiVisionClient implements AiVisionClient {
  GeminiVisionClient(this._http);

  static const _host = 'generativelanguage.googleapis.com';

  // Listed as stable on https://aistudio.google.com/docs/models (checked
  // 2026-11-04). Used until the user picks a model in AI Integration.
  static const fallbackModel = 'gemini-3.6-flash';

  /// Gemini models that don't take photos or don't answer in text.
  static final _notForPhotos = RegExp(
    r'embedding|tts|native-audio|live|imagen|veo|aqa',
  );

  final http.Client _http;

  @override
  String get defaultModel => fallbackModel;

  @override
  Future<String> describeImage({
    required String apiKey,
    required String model,
    required Uint8List imageBytes,
    required String mimeType,
    required String instructions,
  }) async {
    final response = await sendVisionRequest(
      _http,
      Uri.https(_host, '/v1beta/models/$model:generateContent'),
      headers: {..._headers(apiKey), 'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': instructions},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Encode(imageBytes),
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      }),
    );
    _throwUnlessOk(response);

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const AiVisionException(AiVisionFailure.badResponse);
      }
      final parts =
          (candidates.first as Map<String, dynamic>)['content']?['parts']
              as List?;
      final text = parts
          ?.map((part) => (part as Map<String, dynamic>)['text'])
          .whereType<String>()
          .join();
      if (text == null || text.trim().isEmpty) {
        throw const AiVisionException(AiVisionFailure.badResponse);
      }
      return text;
    } on AiVisionException {
      rethrow;
    } catch (_) {
      throw const AiVisionException(AiVisionFailure.badResponse);
    }
  }

  @override
  Future<List<AiModelOption>> listModels({required String apiKey}) async {
    final options = <AiModelOption>[];
    String? pageToken;
    // A few pages at most; guards against a provider that never stops paging.
    for (var page = 0; page < 5; page++) {
      final response = await getVisionResource(
        _http,
        Uri.https(_host, '/v1beta/models', {
          'pageSize': '1000',
          'pageToken': ?pageToken,
        }),
        headers: _headers(apiKey),
      );
      _throwUnlessOk(response);
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        for (final raw in (data['models'] as List? ?? const [])) {
          final model = raw as Map<String, dynamic>;
          final id = (model['name'] as String).replaceFirst('models/', '');
          final methods = model['supportedGenerationMethods'] as List? ?? [];
          if (!id.startsWith('gemini') ||
              !methods.contains('generateContent') ||
              _notForPhotos.hasMatch(id)) {
            continue;
          }
          options.add(
            AiModelOption(id: id, name: model['displayName'] as String?),
          );
        }
        pageToken = data['nextPageToken'] as String?;
      } catch (_) {
        throw const AiVisionException(AiVisionFailure.badResponse);
      }
      if (pageToken == null || pageToken.isEmpty) break;
    }
    // Newer versions sort later alphabetically; show them first.
    return options..sort((a, b) => b.id.compareTo(a.id));
  }

  // The key goes in a header, never the URL, so it can't leak through a
  // logged request URI.
  static Map<String, String> _headers(String apiKey) => {
    'x-goog-api-key': apiKey,
  };

  static void _throwUnlessOk(http.Response response) {
    if (response.statusCode == 200) return;
    logVisionFailure('Gemini', response.statusCode);
    // Gemini answers an invalid key with 400 API_KEY_INVALID.
    if (response.statusCode == 400 &&
        response.body.contains('API_KEY_INVALID')) {
      throw const AiVisionException(AiVisionFailure.invalidKey);
    }
    throw AiVisionException(failureForStatus(response.statusCode));
  }
}
