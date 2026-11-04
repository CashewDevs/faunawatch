import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';

/// Groq and OpenRouter, which both document an OpenAI-compatible API:
/// `/chat/completions` with `image_url` content parts, and `/models`. Their
/// differences (host, default model, extra headers) are set by the named
/// constructors.
class OpenAiCompatibleVisionClient implements AiVisionClient {
  OpenAiCompatibleVisionClient(
    this._http, {
    required this.baseUri,
    required this.defaultModel,
    this.extraHeaders = const {},
  });

  // From https://console.groq.com/docs/vision (checked 2026-11-04). Used
  // until the user picks a model in AI Integration.
  static const groqModel = 'qwen/qwen3.8-27b';

  // Listed with image input at https://openrouter.ai/api/v1/models (checked
  // 2026-11-04). Used until the user picks a model in AI Integration.
  static const openRouterModel = 'google/gemini-2.5-flash';

  /// Models that clearly aren't chat models, for lists that don't say which
  /// models take images (Groq's).
  static final _notForPhotos = RegExp(
    r'whisper|tts|guard|embed|orpheus|playai|moderation',
    caseSensitive: false,
  );

  OpenAiCompatibleVisionClient.groq(http.Client client)
    : this(
        client,
        baseUri: Uri.https('api.groq.com', '/openai/v1/'),
        defaultModel: groqModel,
      );

  OpenAiCompatibleVisionClient.openRouter(http.Client client)
    : this(
        client,
        baseUri: Uri.https('openrouter.ai', '/api/v1/'),
        defaultModel: openRouterModel,
        // Optional attribution headers OpenRouter documents for apps.
        extraHeaders: const {'X-Title': 'FaunaWatch'},
      );

  final http.Client _http;

  /// Ends with `/`, so endpoints resolve beneath it.
  final Uri baseUri;
  final Map<String, String> extraHeaders;

  @override
  final String defaultModel;

  Map<String, String> _headers(String apiKey) => {
    'authorization': 'Bearer $apiKey',
    ...extraHeaders,
  };

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
      baseUri.resolve('chat/completions'),
      headers: {..._headers(apiKey), 'content-type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'temperature': 0.2,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': instructions},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,${base64Encode(imageBytes)}',
                },
              },
            ],
          },
        ],
      }),
    );
    _throwUnlessOk(response);

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      final content = choices == null || choices.isEmpty
          ? null
          : (choices.first as Map<String, dynamic>)['message']?['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const AiVisionException(AiVisionFailure.badResponse);
      }
      return content;
    } on AiVisionException {
      rethrow;
    } catch (_) {
      throw const AiVisionException(AiVisionFailure.badResponse);
    }
  }

  @override
  Future<List<AiModelOption>> listModels({required String apiKey}) async {
    final response = await getVisionResource(
      _http,
      baseUri.resolve('models'),
      headers: _headers(apiKey),
    );
    _throwUnlessOk(response);
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final options = <AiModelOption>[];
      for (final raw in (data['data'] as List? ?? const [])) {
        final model = raw as Map<String, dynamic>;
        final id = model['id'] as String;
        if (model['active'] == false) continue;
        // OpenRouter says which inputs each model takes; Groq doesn't, so
        // there only clearly non-chat models are left out.
        final inputs = (model['architecture'] as Map?)?['input_modalities'];
        if (inputs is List
            ? !inputs.contains('image')
            : _notForPhotos.hasMatch(id)) {
          continue;
        }
        options.add(AiModelOption(id: id, name: model['name'] as String?));
      }
      return options..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {
      throw const AiVisionException(AiVisionFailure.badResponse);
    }
  }

  void _throwUnlessOk(http.Response response) {
    if (response.statusCode == 200) return;
    logVisionFailure(baseUri.host, response.statusCode);
    throw AiVisionException(failureForStatus(response.statusCode));
  }
}
