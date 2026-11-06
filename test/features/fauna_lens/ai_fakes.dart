import 'dart:async';
import 'dart:typed_data';

import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/services/ai_photo_service.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/fauna_lens/services/species_reference_service.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';

/// A finished result for view and ViewModel tests.
AiIdentification sampleIdentification({
  bool invasive = false,
  bool noAnimal = false,
}) {
  final result = AiIdentification(
    animalPresent: !noAnimal,
    possibleSpecies: noAnimal
        ? const []
        : const [
            PossibleSpecies(
              commonName: 'Red-eared Slider',
              scientificName: 'Trachemys scripta elegans',
              confidence: SpeciesConfidence.medium,
            ),
            PossibleSpecies(
              commonName: 'Malayan Box Turtle',
              confidence: SpeciesConfidence.low,
            ),
            PossibleSpecies(commonName: 'Asian Leaf Turtle'),
          ],
    visibleCondition: 'No injury seen in this photo.',
    severity: SeverityLevel.low,
    severityReason: 'The animal looks calm.',
    whatToDo: 'Keep your distance and do not pick up the animal.',
    provider: AiProvider.gemini,
    model: 'test-model',
    promptVersion: 'v-test',
  );
  return invasive ? result.withInvasiveMatch('Red-eared Slider') : result;
}

class FakeKeyStorage implements AiApiKeyStorageService {
  final Map<(String, AiProvider), String> keys = {};

  @override
  Future<String?> readKey(String userId, AiProvider provider) async =>
      keys[(userId, provider)];

  @override
  Future<void> saveKey(
    String userId,
    AiProvider provider,
    String apiKey,
  ) async {
    keys[(userId, provider)] = apiKey;
  }

  @override
  Future<void> deleteKey(String userId, AiProvider provider) async {
    keys.remove((userId, provider));
  }

  @override
  Future<void> deleteAllKeys(String userId) async {
    keys.removeWhere((key, _) => key.$1 == userId);
  }
}

class FakeAiPhotoService implements AiPhotoService {
  bool fails = false;
  final List<String> prepared = [];

  @override
  Future<AiPhoto> prepare(String path) async {
    if (fails) throw const FormatException('bad photo');
    prepared.add(path);
    return AiPhoto(bytes: Uint8List.fromList([7, 7, 7]), mimeType: 'image/png');
  }
}

class FakeVisionClient implements AiVisionClient {
  FakeVisionClient({this.reply = '{}', this.defaultModel = 'fake-model'});

  String reply;
  AiVisionFailure? failure;
  List<AiModelOption> models = const [AiModelOption(id: 'listed-model')];
  final List<String> keysUsed = [];
  final List<String> modelsUsed = [];
  final List<String> mimeTypes = [];
  final List<Uint8List> imagesSent = [];

  @override
  final String defaultModel;

  @override
  Future<String> describeImage({
    required String apiKey,
    required String model,
    required Uint8List imageBytes,
    required String mimeType,
    required String instructions,
  }) async {
    keysUsed.add(apiKey);
    modelsUsed.add(model);
    mimeTypes.add(mimeType);
    imagesSent.add(imageBytes);
    if (failure != null) throw AiVisionException(failure!);
    return reply;
  }

  @override
  Future<List<AiModelOption>> listModels({required String apiKey}) async {
    keysUsed.add(apiKey);
    if (failure != null) throw AiVisionException(failure!);
    return models;
  }
}

class FakePreferencesService implements AiPreferencesService {
  final Map<String, AiPreferences> saved = {};

  @override
  Future<AiPreferences> load(String userId) async =>
      saved[userId] ?? const AiPreferences();

  @override
  Future<void> save(String userId, AiPreferences preferences) async {
    saved[userId] = preferences;
  }
}

class FakeSpeciesReference implements SpeciesReferenceService {
  String? match;
  bool fails = false;
  final List<PossibleSpecies> asked = [];

  @override
  Future<String?> invasiveMatch(PossibleSpecies species) async {
    asked.add(species);
    if (fails) throw Exception('offline');
    return match;
  }
}

/// Stands in for the real service in ViewModel and view tests.
class FakeIdentificationService implements SpeciesIdentificationService {
  AiIdentification? result;
  IdentificationFailure? failure;
  String photoSubject = '';
  final List<String> photoPaths = [];

  /// When set, identify waits for it, holding the screen in its loading state.
  Completer<void>? gate;

  @override
  Future<AiIdentification> identify({
    required String userId,
    required String photoPath,
  }) async {
    photoPaths.add(photoPath);
    await gate?.future;
    if (failure != null) {
      throw IdentificationException(failure!, photoSubject: photoSubject);
    }
    return result ?? sampleIdentification();
  }
}
