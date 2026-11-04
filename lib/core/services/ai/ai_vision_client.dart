import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:faunawatch/core/services/ai/gemini_vision_client.dart';
import 'package:faunawatch/core/services/ai/openai_compatible_vision_client.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';

/// One model a provider offers.
class AiModelOption {
  const AiModelOption({required this.id, String? name}) : name = name ?? id;

  /// What the provider's API expects, e.g. `gemini-3.6-flash`.
  final String id;

  /// Human-readable name, or the ID when the provider gives none.
  final String name;
}

/// Sends one photo plus instructions to an AI provider and returns the text
/// reply, and lists the provider's models. Each provider's request and
/// response format stays inside its own implementation.
abstract interface class AiVisionClient {
  /// The model used when the user hasn't picked one.
  String get defaultModel;

  /// Returns [model]'s text reply. Throws [AiVisionException] on failure.
  ///
  /// [apiKey] is the user's own key; it is only ever sent to the provider.
  Future<String> describeImage({
    required String apiKey,
    required String model,
    required Uint8List imageBytes,
    required String mimeType,
    required String instructions,
  });

  /// Models this provider offers that may accept photos, as far as the
  /// provider's list says. Throws [AiVisionException] on failure.
  Future<List<AiModelOption>> listModels({required String apiKey});
}

/// Why a provider request failed.
enum AiVisionFailure {
  invalidKey,
  rateLimited,
  unavailable,
  network,
  badResponse,
}

/// A provider request failure. Deliberately holds no response body, URL or
/// key, so it is safe to log.
class AiVisionException implements Exception {
  const AiVisionException(this.failure);

  final AiVisionFailure failure;

  @override
  String toString() => 'AiVisionException(${failure.name})';
}

/// How long to wait for a provider before giving up.
const aiVisionTimeout = Duration(seconds: 45);

/// Maps an HTTP status code to a failure. 400 is ambiguous across providers,
/// so callers decide it themselves. 404 means the model no longer exists.
AiVisionFailure failureForStatus(int statusCode) => switch (statusCode) {
  401 || 403 => AiVisionFailure.invalidKey,
  404 => AiVisionFailure.unavailable,
  402 || 429 => AiVisionFailure.rateLimited,
  >= 500 => AiVisionFailure.unavailable,
  _ => AiVisionFailure.badResponse,
};

/// Logs which provider failed and its status code. Never the body or key.
void logVisionFailure(String provider, int statusCode) {
  debugPrint('AiVisionClient: $provider returned HTTP $statusCode');
}

/// Sends a POST and converts transport errors into [AiVisionException].
Future<http.Response> sendVisionRequest(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
  required String body,
}) => _guard(
  () => client.post(uri, headers: headers, body: body).timeout(aiVisionTimeout),
);

/// Sends a GET and converts transport errors into [AiVisionException].
Future<http.Response> getVisionResource(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
}) => _guard(() => client.get(uri, headers: headers).timeout(aiVisionTimeout));

Future<http.Response> _guard(Future<http.Response> Function() send) async {
  try {
    return await send();
  } on TimeoutException {
    throw const AiVisionException(AiVisionFailure.network);
  } on SocketException {
    throw const AiVisionException(AiVisionFailure.network);
  } on http.ClientException {
    throw const AiVisionException(AiVisionFailure.network);
  }
}

/// One vision client per provider, sharing one HTTP client.
final aiVisionClientsProvider = Provider<Map<AiProvider, AiVisionClient>>((
  ref,
) {
  final client = ref.watch(_aiHttpClientProvider);
  return {
    AiProvider.gemini: GeminiVisionClient(client),
    AiProvider.groq: OpenAiCompatibleVisionClient.groq(client),
    AiProvider.openRouter: OpenAiCompatibleVisionClient.openRouter(client),
  };
});

final _aiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});
