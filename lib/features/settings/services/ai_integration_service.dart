import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

/// Why listing models or testing the connection failed.
enum AiIntegrationFailure {
  noKey,
  invalidKey,
  rateLimited,
  unavailable,
  network,
  badResponse,
}

/// Safe to log: holds no key or provider response.
class AiIntegrationException implements Exception {
  const AiIntegrationException(this.failure);

  final AiIntegrationFailure failure;

  @override
  String toString() => 'AiIntegrationException(${failure.name})';
}

/// Lists a provider's models and checks that a key and model work.
///
/// Reads the key from secure storage itself, so it never reaches a
/// ViewModel or View.
class AiIntegrationService {
  AiIntegrationService({
    required this._keys,
    required this._clients,
    Future<Uint8List> Function()? testImage,
  }) : _testImage = testImage ?? _drawTestImage;

  static const testInstructions =
      'This is a connection test. Reply with exactly this JSON and nothing '
      'else: {"ok": true}';

  final AiApiKeyStorageService _keys;
  final Map<AiProvider, AiVisionClient> _clients;
  final Future<Uint8List> Function() _testImage;

  /// Whether each provider has a saved key for [userId].
  Future<Map<AiProvider, bool>> keyStatus(String userId) async => {
    for (final provider in AiProvider.values)
      provider: (await _keys.readKey(userId, provider))?.isNotEmpty ?? false,
  };

  /// The model [provider] uses when the user hasn't picked one.
  String defaultModelFor(AiProvider provider) =>
      _clients[provider]!.defaultModel;

  Future<List<AiModelOption>> listModels({
    required String userId,
    required AiProvider provider,
  }) async {
    final key = await _requireKey(userId, provider);
    return _guard(() => _clients[provider]!.listModels(apiKey: key));
  }

  /// Sends a small generated photo to [model]. Completes normally when the
  /// key works and the model answers a photo.
  Future<void> testConnection({
    required String userId,
    required AiProvider provider,
    required String model,
  }) async {
    final key = await _requireKey(userId, provider);
    final image = await _testImage();
    await _guard(
      () => _clients[provider]!.describeImage(
        apiKey: key,
        model: model,
        imageBytes: image,
        mimeType: 'image/png',
        instructions: testInstructions,
      ),
    );
  }

  Future<String> _requireKey(String userId, AiProvider provider) async {
    final key = await _keys.readKey(userId, provider);
    if (key == null || key.isEmpty) {
      throw const AiIntegrationException(AiIntegrationFailure.noKey);
    }
    return key;
  }

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AiVisionException catch (error) {
      throw AiIntegrationException(switch (error.failure) {
        AiVisionFailure.invalidKey => AiIntegrationFailure.invalidKey,
        AiVisionFailure.rateLimited => AiIntegrationFailure.rateLimited,
        AiVisionFailure.unavailable => AiIntegrationFailure.unavailable,
        AiVisionFailure.network => AiIntegrationFailure.network,
        AiVisionFailure.badResponse => AiIntegrationFailure.badResponse,
      });
    }
  }

  /// A plain 64×64 green square: big enough for every provider to accept as a
  /// photo, small enough to cost almost nothing.
  static Future<Uint8List> _drawTestImage() async {
    const size = 64;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, size * 1.0, size * 1.0),
      ui.Paint()..color = const ui.Color(0xFF2E7D32),
    );
    final image = await recorder.endRecording().toImage(size, size);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}

final aiIntegrationServiceProvider = Provider<AiIntegrationService>(
  (ref) => AiIntegrationService(
    keys: ref.watch(aiApiKeyStorageServiceProvider),
    clients: ref.watch(aiVisionClientsProvider),
  ),
);
