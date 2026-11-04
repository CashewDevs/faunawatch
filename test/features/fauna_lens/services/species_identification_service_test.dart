import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai_fakes.dart';

const _user = 'user-a';
const _reply =
    '{"animal_present": true, "possible_species": ['
    '{"common_name": "Red-eared Slider", "scientific_name": "Trachemys scripta elegans", "confidence": "medium"}], '
    '"visible_condition": "Fine.", "severity": "low", "severity_reason": "Calm.", "what_to_do": "Stay back."}';

void main() {
  late FakeKeyStorage keys;
  late FakeAiPhotoService photos;
  late Map<AiProvider, FakeVisionClient> clients;
  late FakeSpeciesReference references;
  late FakePreferencesService preferences;
  late SpeciesIdentificationService service;

  setUp(() {
    keys = FakeKeyStorage();
    photos = FakeAiPhotoService();
    clients = {
      for (final provider in AiProvider.values)
        provider: FakeVisionClient(
          reply: _reply,
          defaultModel: '${provider.name}-m',
        ),
    };
    references = FakeSpeciesReference();
    preferences = FakePreferencesService();
    service = SpeciesIdentificationService(
      keys: keys,
      photos: photos,
      clients: clients,
      references: references,
      preferences: preferences,
    );
  });

  Future<AiIdentification> identify() =>
      service.identify(userId: _user, photoPath: 'photo.jpg');

  Matcher failsWith(IdentificationFailure failure) => throwsA(
    isA<IdentificationException>().having((e) => e.failure, 'failure', failure),
  );

  test('identifies the photo with the saved key', () async {
    keys.keys[(_user, AiProvider.groq)] = 'groq-key';

    final result = await identify();

    expect(photos.prepared, ['photo.jpg']);
    expect(clients[AiProvider.groq]!.keysUsed, ['groq-key']);
    expect(clients[AiProvider.groq]!.mimeTypes, ['image/png']);
    expect(result.provider, AiProvider.groq);
    expect(result.model, 'groq-m');
    expect(result.promptVersion, SpeciesIdentificationService.promptVersion);
    expect(result.topGuess!.commonName, 'Red-eared Slider');
    expect(result.possibleInvasive, isFalse);
  });

  test('prefers Gemini, then OpenRouter, then Groq', () async {
    keys.keys[(_user, AiProvider.groq)] = 'groq-key';
    keys.keys[(_user, AiProvider.openRouter)] = 'or-key';
    expect((await identify()).provider, AiProvider.openRouter);

    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    expect((await identify()).provider, AiProvider.gemini);
    expect(clients[AiProvider.groq]!.keysUsed, isEmpty);
  });

  test('uses the provider and model the user chose', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    keys.keys[(_user, AiProvider.groq)] = 'groq-key';
    preferences.saved[_user] = const AiPreferences(
      provider: AiProvider.groq,
      models: {AiProvider.groq: 'picked-model'},
    );

    final result = await identify();

    expect(result.provider, AiProvider.groq);
    expect(result.model, 'picked-model');
    expect(clients[AiProvider.groq]!.modelsUsed, ['picked-model']);
    expect(clients[AiProvider.gemini]!.keysUsed, isEmpty);
  });

  test(
    'a chosen provider without a key asks for one, not another provider',
    () async {
      keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
      preferences.saved[_user] = const AiPreferences(
        provider: AiProvider.openRouter,
      );

      await expectLater(
        identify(),
        throwsA(
          isA<IdentificationException>()
              .having((e) => e.failure, 'failure', IdentificationFailure.noKey)
              .having((e) => e.provider, 'provider', AiProvider.openRouter),
        ),
      );
      expect(clients[AiProvider.gemini]!.keysUsed, isEmpty);
    },
  );

  test("never uses another user's key", () async {
    keys.keys[('someone-else', AiProvider.gemini)] = 'their-key';
    await expectLater(identify(), failsWith(IdentificationFailure.noKey));
    expect(photos.prepared, isEmpty);
  });

  test('an unreadable photo is reported before calling the AI', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    photos.fails = true;
    await expectLater(
      identify(),
      failsWith(IdentificationFailure.unreadablePhoto),
    );
    expect(clients[AiProvider.gemini]!.keysUsed, isEmpty);
  });

  test('maps each provider failure', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    const expected = {
      AiVisionFailure.invalidKey: IdentificationFailure.invalidKey,
      AiVisionFailure.rateLimited: IdentificationFailure.rateLimited,
      AiVisionFailure.unavailable: IdentificationFailure.unavailable,
      AiVisionFailure.network: IdentificationFailure.network,
      AiVisionFailure.badResponse: IdentificationFailure.badResponse,
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      clients[AiProvider.gemini]!.failure = key;
      await expectLater(identify(), failsWith(value));
    }
  });

  test('a reply that is not JSON is a bad response', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    clients[AiProvider.gemini]!.reply = 'Sorry, I cannot help.';
    await expectLater(identify(), failsWith(IdentificationFailure.badResponse));
  });

  test('flags a possible invasive species from the reference list', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    references.match = 'Red-eared Slider';

    final result = await identify();

    expect(references.asked.single.scientificName, 'Trachemys scripta elegans');
    expect(result.possibleInvasive, isTrue);
    expect(result.invasiveMatch, 'Red-eared Slider');
  });

  test('a failed reference lookup still returns the result', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    references.fails = true;

    final result = await identify();

    expect(result.topGuess!.commonName, 'Red-eared Slider');
    expect(result.possibleInvasive, isFalse);
  });

  test('no reference lookup when there is no animal', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    clients[AiProvider.gemini]!.reply =
        '{"animal_present": false, "possible_species": []}';

    final result = await identify();

    expect(result.hasSpecies, isFalse);
    expect(references.asked, isEmpty);
  });
}
