import 'dart:async';
import 'dart:typed_data';

import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/services/ai_photo_service.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/fauna_lens/services/species_reference_service.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';

/// A box found by the AI, for tests.
AnimalBox sampleBox({
  AnimalBoxColor color = AnimalBoxColor.red,
  String name = 'turtle',
  double left = 0.1,
  double top = 0.2,
  double right = 0.5,
  double bottom = 0.6,
}) => AnimalBox(
  left: left,
  top: top,
  right: right,
  bottom: bottom,
  color: color,
  name: name,
);

/// The curated reference entry used for invasive results in tests.
const sampleInvasiveMatch = SpeciesReferenceMatch(
  id: '00000000-0000-0000-0000-00000000000a',
  commonName: 'Red-eared Slider',
);

/// A finished result for view and ViewModel tests.
AiIdentification sampleIdentification({
  bool invasive = false,
  bool noAnimal = false,
  ReportCategory category = ReportCategory.otherWildlifeIncident,
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
    aiCategory: category,
  );
  return invasive ? result.withInvasiveMatch(sampleInvasiveMatch) : result;
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

class FakeBackupKeyStorage implements AiBackupKeyStorageService {
  final Map<String, (AiProvider, String)> backups = {};
  Object? saveError;

  @override
  Future<AiProvider?> readProvider(String userId) async => backups[userId]?.$1;

  @override
  Future<String?> readKey(String userId) async => backups[userId]?.$2;

  @override
  Future<void> save(String userId, AiProvider provider, String apiKey) async {
    if (saveError != null) throw saveError!;
    backups[userId] = (provider, apiKey.trim());
  }

  @override
  Future<void> delete(String userId) async {
    backups.remove(userId);
  }
}

class FakeAiPhotoService implements AiPhotoService {
  bool fails = false;
  final List<String> prepared = [];

  /// The boxes drawn on each prepared photo.
  final List<List<AnimalBox>> boxesDrawn = [];

  @override
  Future<AiPhoto> prepare(
    String path, {
    List<AnimalBox> boxes = const [],
  }) async {
    if (fails) throw const FormatException('bad photo');
    prepared.add(path);
    boxesDrawn.add(boxes);
    return AiPhoto(bytes: Uint8List.fromList([7, 7, 7]), mimeType: 'image/png');
  }
}

class FakeVisionClient implements AiVisionClient {
  FakeVisionClient({this.reply = '{}', this.defaultModel = 'fake-model'});

  String reply;
  final List<String> instructionsSent = [];
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
    instructionsSent.add(instructions);
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
  SpeciesReferenceMatch? match;
  bool fails = false;
  final List<PossibleSpecies> asked = [];

  @override
  Future<SpeciesReferenceMatch?> invasiveMatch(PossibleSpecies species) async {
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
  final List<List<AnimalBox>> boxesAnalysed = [];

  /// What findAnimals returns; one box by default.
  List<AnimalBox> found = [sampleBox()];
  IdentificationFailure? findFailure;
  final List<String> searchedPaths = [];

  /// When set, identify waits for it, holding the screen in its loading state.
  Completer<void>? gate;

  /// When set, findAnimals waits for it.
  Completer<void>? findGate;

  @override
  Future<List<AnimalBox>> findAnimals({
    required String userId,
    required String photoPath,
  }) async {
    searchedPaths.add(photoPath);
    await findGate?.future;
    if (findFailure != null) throw IdentificationException(findFailure!);
    return found;
  }

  @override
  Future<AiIdentification> identify({
    required String userId,
    required String photoPath,
    required List<AnimalBox> boxes,
  }) async {
    photoPaths.add(photoPath);
    boxesAnalysed.add(boxes);
    await gate?.future;
    if (failure != null) {
      throw IdentificationException(failure!, photoSubject: photoSubject);
    }
    return result ?? sampleIdentification();
  }
}
