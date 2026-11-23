import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/services/ai_photo_service.dart';
import 'package:faunawatch/features/fauna_lens/services/species_reference_service.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';

/// Asks the user's AI provider about a FaunaLens photo: where the animals
/// are, and what the chosen ones are.
///
/// Reads the key from secure storage itself, so the key never reaches a
/// ViewModel or View.
class SpeciesIdentificationService {
  SpeciesIdentificationService({
    required this._keys,
    required this._backupKeys,
    required this._photos,
    required this._clients,
    required this._references,
    required this._preferences,
  });

  /// Bump whenever [instructionsFor] changes, so stored results can be told
  /// apart.
  static const promptVersion = 'fauna_lens_identify_v4';

  /// Instructions for finding the animals. The reply is read by
  /// [AnimalBox.listFromModelReply]; boxes are never saved.
  static final findInstructions =
      '''
You are helping a wildlife reporting app. Find every animal in the photo: mammals, birds, reptiles, amphibians, fish, insects and other wildlife or pets. Do not include people. Reply with only a JSON object, no other text, in exactly this shape:
{"animals": [{"name": "", "box_2d": [0, 0, 0, 0]}]}

Rules:
- One entry per animal, at most ${AnimalBox.maxBoxes}, the most noticeable first.
- name: one to three plain words, such as "brown dog" or "heron".
- box_2d: a tight box around the whole animal as [ymin, xmin, ymax, xmax], each a whole number from 0 to 1000, where [0, 0] is the top-left corner of the photo and [1000, 1000] the bottom-right.
- If there is no animal, reply {"animals": []}.''';

  /// Instructions for analysing the animals in [boxes], which are drawn on
  /// the photo the AI receives.
  static String instructionsFor(List<AnimalBox> boxes) {
    final several = boxes.length > 1;
    final boxList = [
      for (final box in boxes)
        '- the ${box.color.value} box, ${box.positionDescription}',
    ].join('\n');
    final speciesShape = several
        ? '{"box": "${boxes.first.color.value}", "common_name": "", '
              '"scientific_name": "", "confidence": "high"}'
        : '{"common_name": "", "scientific_name": "", "confidence": "high"}';
    final speciesRule = several
        ? 'possible_species: exactly one entry per box, in the order listed '
              'above. "box" is the colour of the box, with your single best '
              'guess for the animal in it.'
        : 'possible_species: at most 3 guesses for the animal in the box, '
              'most likely first.';
    final inside = several ? 'any of the boxes' : 'the box';
    final animals = several ? 'the animals' : 'the animal';

    return '''
You are helping a wildlife reporting app. The user drew ${several ? '${boxes.length} coloured boxes' : 'a coloured box'} on the photo:
$boxList
Only look at the animal inside ${several ? 'each of these boxes' : 'that box'}. Ignore everything else in the photo, including other animals. The boxes are not part of the scene; do not describe them. Reply with only a JSON object, no other text, in exactly this shape:
{"animal_present": true, "photo_subject": "", "possible_species": [$speciesShape], "visible_condition": "", "severity": "low", "severity_reason": "", "category": "other_wildlife_incident", "what_to_do": ""}

Rules:
- animal_present: false if there is no animal inside $inside (for example a person only, an object, food, a plant, a landscape, a screenshot or a drawing). Then possible_species must be [].
- photo_subject: a few plain words on what $inside mainly shows, such as "a coffee mug on a desk". Never name or identify a person.
- $speciesRule confidence is one of "high", "medium", "low", "uncertain". Never give percentages.
- visible_condition: one or two short sentences about any injury or distress you can see${several ? ', naming the box colour of each animal you mention' : ''}. Say what a single photo cannot show.
- severity: one of "low", "moderate", "high", "critical", "uncertain": how urgently $animals or people nearby may need help, based only on the photo.${several ? ' Use the most urgent of the animals.' : ''}
- severity_reason: one short sentence explaining the severity.
- category: one for the whole report, one of "animal_in_need" (an animal looks injured or distressed and needs help), "potentially_dangerous_animal" (an animal that may endanger people nearby), "other_wildlife_incident" (anything else).
- what_to_do: one to three short sentences of safe, practical advice for a member of the public. Never tell them to touch, pick up, feed or handle a wild animal.
- Do not say whether any species is invasive.
- Use plain, simple English.''';
  }

  final AiApiKeyStorageService _keys;
  final AiBackupKeyStorageService _backupKeys;
  final AiPhotoService _photos;
  final Map<AiProvider, AiVisionClient> _clients;
  final SpeciesReferenceService _references;
  final AiPreferencesService _preferences;

  /// Finds the animals in the photo, each with its own coloured box. An empty
  /// list means the AI saw no animal. Throws [IdentificationException].
  Future<List<AnimalBox>> findAnimals({
    required String userId,
    required String photoPath,
  }) async {
    final answer = await _ask(
      userId: userId,
      photoPath: photoPath,
      instructions: findInstructions,
    );
    try {
      return AnimalBox.listFromModelReply(answer.reply);
    } on FormatException {
      throw IdentificationException(
        IdentificationFailure.badResponse,
        provider: answer.provider,
      );
    }
  }

  /// One combined analysis of the animals in [boxes] (one to
  /// [AnimalBox.maxChosen]).
  ///
  /// Throws [IdentificationException] when no result can be produced,
  /// including [IdentificationFailure.notAnimal] when the boxes show no
  /// animal.
  Future<AiIdentification> identify({
    required String userId,
    required String photoPath,
    required List<AnimalBox> boxes,
  }) async {
    if (boxes.isEmpty || boxes.length > AnimalBox.maxChosen) {
      throw ArgumentError.value(
        boxes.length,
        'boxes',
        'must be 1 to ${AnimalBox.maxChosen}',
      );
    }
    final answer = await _ask(
      userId: userId,
      photoPath: photoPath,
      instructions: instructionsFor(boxes),
      boxes: boxes,
    );
    final provider = answer.provider;

    AiIdentification result;
    try {
      result = AiIdentification.fromModelReply(
        answer.reply,
        provider: provider,
        model: answer.model,
        promptVersion: promptVersion,
        boxes: boxes,
      );
    } on FormatException {
      throw IdentificationException(
        IdentificationFailure.badResponse,
        provider: provider,
      );
    }
    if (answer.backupKeyUse != null) {
      result = result.withBackupKeyUse(answer.backupKeyUse!);
    }

    if (result.animalPresent == false) {
      throw IdentificationException(
        IdentificationFailure.notAnimal,
        provider: provider,
        photoSubject: result.photoSubject,
      );
    }

    // The database keeps one match: the first guess that has one.
    for (final guess in result.guessesToCheck) {
      try {
        final match = await _references.invasiveMatch(guess);
        if (match != null) return result.withInvasiveMatch(match);
      } catch (error) {
        // The hint is optional; the rest of the result is still useful.
        debugPrint('SpeciesIdentificationService: reference lookup failed');
        return result;
      }
    }
    return result;
  }

  /// Main-key failures a different key might get past: the key was rejected,
  /// is out of quota or busy, or its provider (or model) is down. Not network
  /// problems, unreadable photos or odd replies, which another key can't fix.
  static const _backupHelps = {
    IdentificationFailure.invalidKey,
    IdentificationFailure.rateLimited,
    IdentificationFailure.unavailable,
  };

  static IdentificationFailure _failureFor(AiVisionFailure failure) =>
      switch (failure) {
        AiVisionFailure.invalidKey => IdentificationFailure.invalidKey,
        AiVisionFailure.rateLimited => IdentificationFailure.rateLimited,
        AiVisionFailure.unavailable => IdentificationFailure.unavailable,
        AiVisionFailure.network => IdentificationFailure.network,
        AiVisionFailure.badResponse => IdentificationFailure.badResponse,
      };

  /// Sends the prepared photo, with [boxes] drawn on it, and [instructions]
  /// to the user's provider. If the main key fails in a way another key
  /// might get past, tries the backup key once with the same photo. Throws
  /// the main key's failure when both fail.
  Future<_Answer> _ask({
    required String userId,
    required String photoPath,
    required String instructions,
    List<AnimalBox> boxes = const [],
  }) async {
    final preferences = await _preferences.load(userId);
    final (provider, apiKey, model) = await _choose(userId, preferences);

    final AiPhoto photo;
    try {
      photo = await _photos.prepare(photoPath, boxes: boxes);
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

    Future<String> send(AiProvider provider, String apiKey, String model) =>
        _clients[provider]!.describeImage(
          apiKey: apiKey,
          model: model,
          imageBytes: photo.bytes,
          mimeType: photo.mimeType,
          instructions: instructions,
        );

    final IdentificationFailure mainFailure;
    try {
      return _Answer(provider, model, await send(provider, apiKey, model));
    } on AiVisionException catch (error) {
      mainFailure = _failureFor(error.failure);
    }

    if (_backupHelps.contains(mainFailure)) {
      final backup = await _backup(userId, preferences);
      if (backup != null) {
        final (backupProvider, backupKey, backupModel) = backup;
        // Only the failure kinds are logged, never a key or reply.
        debugPrint(
          'SpeciesIdentificationService: main key failed '
          '(${mainFailure.name}), trying the backup key',
        );
        try {
          return _Answer(
            backupProvider,
            backupModel,
            await send(backupProvider, backupKey, backupModel),
            backupKeyUse: BackupKeyUse(
              mainFailure: mainFailure,
              mainProvider: provider,
            ),
          );
        } on AiVisionException catch (error) {
          debugPrint(
            'SpeciesIdentificationService: backup key failed too '
            '(${error.failure.name})',
          );
        }
      }
    }
    throw IdentificationException(mainFailure, provider: provider);
  }

  /// The backup's provider, key and model (the backup's own model choice for
  /// that provider, else its default), or null when there is no backup key.
  Future<(AiProvider, String, String)?> _backup(
    String userId,
    AiPreferences preferences,
  ) async {
    try {
      final provider = await _backupKeys.readProvider(userId);
      final key = await _backupKeys.readKey(userId);
      if (provider == null || key == null || key.isEmpty) return null;
      final model =
          preferences.backupModels[provider] ??
          _clients[provider]!.defaultModel;
      return (provider, key, model);
    } catch (error) {
      // A storage problem with the backup must not hide the main failure.
      debugPrint('SpeciesIdentificationService: backup key unreadable');
      return null;
    }
  }

  /// The provider, key and model to use. A provider the user chose is used
  /// even without a key (they are asked to add one) rather than silently
  /// billing another provider. Without a choice, the first provider in
  /// [AiProvider.fallbackOrder] with a key is used. The backup key is never
  /// chosen here: it is only tried after the main key fails.
  Future<(AiProvider, String, String)> _choose(
    String userId,
    AiPreferences preferences,
  ) async {
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

/// A provider's reply and who gave it.
class _Answer {
  const _Answer(this.provider, this.model, this.reply, {this.backupKeyUse});

  /// The provider and model that answered: the backup's when
  /// [backupKeyUse] is set.
  final AiProvider provider;
  final String model;
  final String reply;
  final BackupKeyUse? backupKeyUse;
}

final speciesIdentificationServiceProvider =
    Provider<SpeciesIdentificationService>(
      (ref) => SpeciesIdentificationService(
        keys: ref.watch(aiApiKeyStorageServiceProvider),
        backupKeys: ref.watch(aiBackupKeyStorageServiceProvider),
        photos: ref.watch(aiPhotoServiceProvider),
        clients: ref.watch(aiVisionClientsProvider),
        references: ref.watch(speciesReferenceServiceProvider),
        preferences: ref.watch(aiPreferencesServiceProvider),
      ),
    );
