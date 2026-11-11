import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/services/ai_photo_service.dart';
import 'package:faunawatch/features/fauna_lens/services/species_reference_service.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';

/// Asks the user's AI provider what animal is in a FaunaLens photo.
///
/// Reads the key from secure storage itself, so the key never reaches a
/// ViewModel or View.
class SpeciesIdentificationService {
  SpeciesIdentificationService({
    required this._keys,
    required this._photos,
    required this._clients,
    required this._references,
    required this._preferences,
  });

  /// Bump whenever [instructions] change, so stored results can be told apart.
  static const promptVersion = 'fauna_lens_identify_v3';

  static const instructions = '''
You are helping a wildlife reporting app. Look at the photo and reply with only a JSON object, no other text, in exactly this shape:
{"animal_present": true, "photo_subject": "", "possible_species": [{"common_name": "", "scientific_name": "", "confidence": "high"}], "visible_condition": "", "severity": "low", "severity_reason": "", "category": "other_wildlife_incident", "what_to_do": ""}

Rules:
- animal_present: false if no animal is visible (for example a person only, an object, food, a plant, a landscape, a screenshot or a drawing). Then possible_species must be [].
- photo_subject: a few plain words on what the photo mainly shows, such as "a coffee mug on a desk". Never name or identify a person.
- possible_species: at most 3 guesses, most likely first. confidence is one of "high", "medium", "low", "uncertain". Never give percentages.
- visible_condition: one or two short sentences about any injury or distress you can see. Say what a single photo cannot show.
- severity: one of "low", "moderate", "high", "critical", "uncertain": how urgently the animal or people nearby may need help, based only on the photo.
- severity_reason: one short sentence explaining the severity.
- category: one of "animal_in_need" (the animal looks injured or distressed and needs help), "potentially_dangerous_animal" (an animal that may endanger people nearby), "other_wildlife_incident" (anything else).
- what_to_do: one to three short sentences of safe, practical advice for a member of the public. Never tell them to touch, pick up, feed or handle a wild animal.
- Do not say whether the species is invasive.
- Use plain, simple English.''';

  final AiApiKeyStorageService _keys;
  final AiPhotoService _photos;
  final Map<AiProvider, AiVisionClient> _clients;
  final SpeciesReferenceService _references;
  final AiPreferencesService _preferences;

  /// Throws [IdentificationException] when no result can be produced,
  /// including [IdentificationFailure.notAnimal] when the photo shows no
  /// animal.
  Future<AiIdentification> identify({
    required String userId,
    required String photoPath,
  }) async {
    final (provider, apiKey, model) = await _choose(userId);
    final client = _clients[provider]!;

    final AiPhoto photo;
    try {
      photo = await _photos.prepare(photoPath);
    } catch (error) {
      // Only the type is logged, which is enough to tell platform problems
      // apart from damaged photos.
      debugPrint(
        'SpeciesIdentificationService: photo prep failed '
        '(${error.runtimeType})',
      );
      throw IdentificationException(
        IdentificationFailure.unreadablePhoto,
        provider: provider,
      );
    }

    final String reply;
    try {
      reply = await client.describeImage(
        apiKey: apiKey,
        model: model,
        imageBytes: photo.bytes,
        mimeType: photo.mimeType,
        instructions: instructions,
      );
    } on AiVisionException catch (error) {
      throw IdentificationException(switch (error.failure) {
        AiVisionFailure.invalidKey => IdentificationFailure.invalidKey,
        AiVisionFailure.rateLimited => IdentificationFailure.rateLimited,
        AiVisionFailure.unavailable => IdentificationFailure.unavailable,
        AiVisionFailure.network => IdentificationFailure.network,
        AiVisionFailure.badResponse => IdentificationFailure.badResponse,
      }, provider: provider);
    }

    final AiIdentification result;
    try {
      result = AiIdentification.fromModelReply(
        reply,
        provider: provider,
        model: model,
        promptVersion: promptVersion,
      );
    } on FormatException {
      throw IdentificationException(
        IdentificationFailure.badResponse,
        provider: provider,
      );
    }

    if (result.animalPresent == false) {
      throw IdentificationException(
        IdentificationFailure.notAnimal,
        provider: provider,
        photoSubject: result.photoSubject,
      );
    }

    final top = result.topGuess;
    if (top == null) return result;
    try {
      return result.withInvasiveMatch(await _references.invasiveMatch(top));
    } catch (error) {
      // The hint is optional; the rest of the result is still useful.
      debugPrint('SpeciesIdentificationService: reference lookup failed');
      return result;
    }
  }

  /// The provider, key and model to use. A provider the user chose is used
  /// even without a key (they are asked to add one) rather than silently
  /// billing another provider. Without a choice, the first provider in
  /// [AiProvider.fallbackOrder] with a key is used.
  Future<(AiProvider, String, String)> _choose(String userId) async {
    final preferences = await _preferences.load(userId);
    final candidates = preferences.provider == null
        ? AiProvider.fallbackOrder
        : [preferences.provider!];
    for (final provider in candidates) {
      final key = await _keys.readKey(userId, provider);
      if (key != null && key.isNotEmpty) {
        final model =
            preferences.models[provider] ?? _clients[provider]!.defaultModel;
        return (provider, key, model);
      }
    }
    throw IdentificationException(
      IdentificationFailure.noKey,
      provider: preferences.provider,
    );
  }
}

final speciesIdentificationServiceProvider =
    Provider<SpeciesIdentificationService>(
      (ref) => SpeciesIdentificationService(
        keys: ref.watch(aiApiKeyStorageServiceProvider),
        photos: ref.watch(aiPhotoServiceProvider),
        clients: ref.watch(aiVisionClientsProvider),
        references: ref.watch(speciesReferenceServiceProvider),
        preferences: ref.watch(aiPreferencesServiceProvider),
      ),
    );
