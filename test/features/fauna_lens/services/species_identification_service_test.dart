import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
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
  late FakeBackupKeyStorage backups;
  late FakeAiPhotoService photos;
  late Map<AiProvider, FakeVisionClient> clients;
  late FakeSpeciesReference references;
  late FakePreferencesService preferences;
  late SpeciesIdentificationService service;

  setUp(() {
    keys = FakeKeyStorage();
    backups = FakeBackupKeyStorage();
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
      backupKeys: backups,
      photos: photos,
      clients: clients,
      references: references,
      preferences: preferences,
    );
  });

  Future<AiIdentification> identify({List<AnimalBox>? boxes}) =>
      service.identify(
        userId: _user,
        photoPath: 'photo.jpg',
        boxes: boxes ?? [sampleBox()],
      );

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

  test('prompt v4 asks for a category but not the invasive one', () async {
    keys.keys[(_user, AiProvider.groq)] = 'groq-key';
    await identify();
    expect(
      SpeciesIdentificationService.promptVersion,
      'fauna_lens_identify_v4',
    );
    final prompt = clients[AiProvider.groq]!.instructionsSent.single;
    expect(prompt, contains('"category"'));
    expect(prompt, contains('animal_in_need'));
    expect(prompt, contains('potentially_dangerous_animal'));
    expect(prompt, contains('other_wildlife_incident'));
    expect(prompt, isNot(contains('possible_invasive_species')));
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

  group('backup key', () {
    setUp(() {
      keys.keys[(_user, AiProvider.gemini)] = 'main-gemini';
      backups.backups[_user] = (AiProvider.groq, 'backup-groq');
    });

    Matcher failsFrom(IdentificationFailure failure, AiProvider provider) =>
        throwsA(
          isA<IdentificationException>()
              .having((e) => e.failure, 'failure', failure)
              .having((e) => e.provider, 'provider', provider),
        );

    for (final (failure, expected) in [
      (AiVisionFailure.invalidKey, IdentificationFailure.invalidKey),
      (AiVisionFailure.rateLimited, IdentificationFailure.rateLimited),
      (AiVisionFailure.unavailable, IdentificationFailure.unavailable),
    ]) {
      test(
        'is tried once when the main key fails with ${failure.name}',
        () async {
          clients[AiProvider.gemini]!.failure = failure;

          final result = await identify();

          expect(clients[AiProvider.gemini]!.keysUsed, ['main-gemini']);
          expect(clients[AiProvider.groq]!.keysUsed, ['backup-groq']);
          // The photo is prepared once and the same one goes to the backup.
          expect(photos.prepared, ['photo.jpg']);
          expect(
            clients[AiProvider.groq]!.imagesSent.single,
            clients[AiProvider.gemini]!.imagesSent.single,
          );
          expect(
            clients[AiProvider.groq]!.instructionsSent.single,
            clients[AiProvider.gemini]!.instructionsSent.single,
          );
          expect(result.provider, AiProvider.groq);
          expect(result.model, 'groq-m');
          expect(result.usedBackupKey, isTrue);
          expect(
            result.backupKeyUse,
            BackupKeyUse(
              mainFailure: expected,
              mainProvider: AiProvider.gemini,
            ),
          );
        },
      );
    }

    for (final failure in [
      AiVisionFailure.network,
      AiVisionFailure.badResponse,
    ]) {
      test(
        'is not tried when the main call fails with ${failure.name}',
        () async {
          clients[AiProvider.gemini]!.failure = failure;
          await expectLater(
            identify(),
            throwsA(isA<IdentificationException>()),
          );
          expect(clients[AiProvider.groq]!.keysUsed, isEmpty);
        },
      );
    }

    test('is not used when the main key works', () async {
      final result = await identify();
      expect(result.provider, AiProvider.gemini);
      expect(result.usedBackupKey, isFalse);
      expect(clients[AiProvider.groq]!.keysUsed, isEmpty);
    });

    test('is not tried for an unreadable photo', () async {
      photos.fails = true;
      await expectLater(
        identify(),
        failsWith(IdentificationFailure.unreadablePhoto),
      );
      expect(clients[AiProvider.groq]!.keysUsed, isEmpty);
    });

    test('does not stand in for a missing main key', () async {
      keys.keys.clear();
      await expectLater(identify(), failsWith(IdentificationFailure.noKey));
      expect(clients[AiProvider.groq]!.keysUsed, isEmpty);
    });

    test('can be a second key for the same provider', () async {
      backups.backups[_user] = (AiProvider.gemini, 'backup-gemini');
      clients[AiProvider.gemini]!.failByKey['main-gemini'] =
          AiVisionFailure.rateLimited;

      final result = await identify();

      expect(clients[AiProvider.gemini]!.keysUsed, [
        'main-gemini',
        'backup-gemini',
      ]);
      expect(result.provider, AiProvider.gemini);
      expect(result.backupKeyUse!.mainProvider, AiProvider.gemini);
    });

    test("uses the backup's own model, not the main pick", () async {
      preferences.saved[_user] = const AiPreferences(
        provider: AiProvider.gemini,
        models: {AiProvider.gemini: 'g-picked', AiProvider.groq: 'q-main'},
        backupModels: {AiProvider.groq: 'q-backup'},
      );
      clients[AiProvider.gemini]!.failure = AiVisionFailure.rateLimited;

      final result = await identify();

      expect(clients[AiProvider.gemini]!.modelsUsed, ['g-picked']);
      expect(clients[AiProvider.groq]!.modelsUsed, ['q-backup']);
      expect(result.model, 'q-backup');
    });

    test(
      "without its own pick, the backup uses its provider's default",
      () async {
        preferences.saved[_user] = const AiPreferences(
          provider: AiProvider.gemini,
          models: {AiProvider.groq: 'q-main'},
        );
        clients[AiProvider.gemini]!.failure = AiVisionFailure.rateLimited;

        final result = await identify();

        expect(result.model, clients[AiProvider.groq]!.defaultModel);
      },
    );

    test("when both fail, the main key's failure is reported", () async {
      clients[AiProvider.gemini]!.failure = AiVisionFailure.rateLimited;
      clients[AiProvider.groq]!.failure = AiVisionFailure.invalidKey;

      await expectLater(
        identify(),
        failsFrom(IdentificationFailure.rateLimited, AiProvider.gemini),
      );
      expect(clients[AiProvider.groq]!.keysUsed, ['backup-groq']);
    });

    test('an unreadable backup store still reports the main failure', () async {
      backups.readError = StateError('keystore locked');
      clients[AiProvider.gemini]!.failure = AiVisionFailure.unavailable;

      await expectLater(
        identify(),
        failsFrom(IdentificationFailure.unavailable, AiProvider.gemini),
      );
    });

    test('without a backup, failures are unchanged', () async {
      backups.backups.clear();
      clients[AiProvider.gemini]!.failure = AiVisionFailure.invalidKey;
      await expectLater(
        identify(),
        failsFrom(IdentificationFailure.invalidKey, AiProvider.gemini),
      );
    });

    test('the invasive hint keeps the backup note', () async {
      references.match = sampleInvasiveMatch;
      clients[AiProvider.gemini]!.failure = AiVisionFailure.rateLimited;

      final result = await identify();

      expect(result.possibleInvasive, isTrue);
      expect(result.usedBackupKey, isTrue);
    });

    test('finding the animals falls back too', () async {
      clients[AiProvider.gemini]!.failure = AiVisionFailure.invalidKey;
      clients[AiProvider.groq]!.reply =
          '{"animals": [{"name": "turtle", "box_2d": [100, 100, 600, 500]}]}';

      final boxes = await service.findAnimals(
        userId: _user,
        photoPath: 'photo.jpg',
      );

      expect(boxes, hasLength(1));
      expect(clients[AiProvider.groq]!.keysUsed, ['backup-groq']);
    });
  });

  test('a reply that is not JSON is a bad response', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    clients[AiProvider.gemini]!.reply = 'Sorry, I cannot help.';
    await expectLater(identify(), failsWith(IdentificationFailure.badResponse));
  });

  test('flags a possible invasive species from the reference list', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    references.match = sampleInvasiveMatch;

    final result = await identify();

    expect(references.asked.single.scientificName, 'Trachemys scripta elegans');
    expect(result.possibleInvasive, isTrue);
    expect(result.invasiveMatch, sampleInvasiveMatch);
  });

  test(
    'the category comes from the reply, and a match forces invasive',
    () async {
      keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
      clients[AiProvider.gemini]!.reply = _reply.replaceFirst(
        '"severity"',
        '"category": "animal_in_need", "severity"',
      );
      expect((await identify()).category, ReportCategory.animalInNeed);

      references.match = sampleInvasiveMatch;
      final matched = await identify();
      expect(matched.category, ReportCategory.possibleInvasiveSpecies);
      expect(matched.aiCategory, ReportCategory.animalInNeed);
    },
  );

  test('a failed reference lookup still returns the result', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    references.fails = true;

    final result = await identify();

    expect(result.topGuess!.commonName, 'Red-eared Slider');
    expect(result.possibleInvasive, isFalse);
  });

  test(
    'a photo without an animal fails as notAnimal with its subject',
    () async {
      keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
      clients[AiProvider.gemini]!.reply =
          '{"animal_present": false, "photo_subject": "a coffee mug", '
          '"possible_species": []}';

      await expectLater(
        identify(),
        throwsA(
          isA<IdentificationException>()
              .having(
                (e) => e.failure,
                'failure',
                IdentificationFailure.notAnimal,
              )
              .having((e) => e.photoSubject, 'photoSubject', 'a coffee mug')
              .having((e) => e.provider, 'provider', AiProvider.gemini),
        ),
      );
      expect(references.asked, isEmpty);
    },
  );

  group('with boxes', () {
    final red = sampleBox();
    final blue = sampleBox(
      color: AnimalBoxColor.blue,
      name: 'heron',
      left: 0.6,
      right: 0.9,
    );

    test('draws the chosen box on the photo and points the AI at it', () async {
      keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
      await identify(boxes: [red]);

      expect(photos.boxesDrawn.single, [red]);
      final prompt = clients[AiProvider.gemini]!.instructionsSent.single;
      expect(prompt, contains('the red box, from 10% to 50% across'));
      expect(prompt, contains('at most 3 guesses for the animal in the box'));
      expect(prompt, isNot(contains('blue')));
    });

    test('several animals get one guess each, tied to their box', () async {
      keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
      clients[AiProvider.gemini]!.reply =
          '{"animal_present": true, "possible_species": ['
          '{"box": "blue", "common_name": "Grey Heron", "confidence": "high"}, '
          '{"box": "red", "common_name": "Red-eared Slider", "confidence": "medium"}, '
          '{"box": "red", "common_name": "Extra", "confidence": "low"}], '
          '"severity": "moderate"}';

      final result = await identify(boxes: [red, blue]);

      expect(photos.boxesDrawn.single, [red, blue]);
      final prompt = clients[AiProvider.gemini]!.instructionsSent.single;
      expect(prompt, contains('2 coloured boxes'));
      expect(prompt, contains('the red box'));
      expect(prompt, contains('the blue box'));
      expect(prompt, contains('exactly one entry per box'));
      expect(result.animalCount, 2);
      expect(result.possibleSpecies.map((s) => s.commonName), [
        'Grey Heron',
        'Red-eared Slider',
      ]);
      expect(result.possibleSpecies.map((s) => s.boxColor), [
        AnimalBoxColor.blue,
        AnimalBoxColor.red,
      ]);
      expect(result.speciesSummary, 'Grey Heron, Red-eared Slider');
    });

    test(
      'several animals: each guess is checked against the invasive list',
      () async {
        keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
        clients[AiProvider.gemini]!.reply =
            '{"possible_species": ['
            '{"box": "red", "common_name": "Grey Heron"}, '
            '{"box": "blue", "common_name": "Red-eared Slider"}]}';
        references.match = null;

        final plain = await identify(boxes: [red, blue]);
        expect(references.asked.map((s) => s.commonName), [
          'Grey Heron',
          'Red-eared Slider',
        ]);
        expect(plain.possibleInvasive, isFalse);

        references.asked.clear();
        references.match = sampleInvasiveMatch;
        final matched = await identify(boxes: [red, blue]);
        // The first match is kept; there is room for only one.
        expect(references.asked, hasLength(1));
        expect(matched.invasiveMatch, sampleInvasiveMatch);
      },
    );

    test('needs one to three boxes', () async {
      keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
      await expectLater(identify(boxes: []), throwsArgumentError);
      await expectLater(
        identify(boxes: [red, blue, red, blue]),
        throwsArgumentError,
      );
      expect(clients[AiProvider.gemini]!.instructionsSent, isEmpty);
    });
  });

  group('findAnimals', () {
    Future<List<AnimalBox>> find() =>
        service.findAnimals(userId: _user, photoPath: 'photo.jpg');

    test('asks the chosen provider for boxes on the plain photo', () async {
      keys.keys[(_user, AiProvider.openRouter)] = 'or-key';
      preferences.saved[_user] = const AiPreferences(
        provider: AiProvider.openRouter,
      );
      clients[AiProvider.openRouter]!.reply =
          '{"animals": [{"name": "dog", "box_2d": [100, 200, 600, 700]}]}';

      final boxes = await find();

      expect(clients[AiProvider.openRouter]!.keysUsed, ['or-key']);
      expect(photos.boxesDrawn.single, isEmpty);
      final prompt = clients[AiProvider.openRouter]!.instructionsSent.single;
      expect(prompt, contains('box_2d'));
      expect(prompt, contains('[ymin, xmin, ymax, xmax]'));
      expect(boxes.single.name, 'dog');
      expect(boxes.single.left, closeTo(0.2, 1e-9));
      expect(boxes.single.top, closeTo(0.1, 1e-9));
      expect(boxes.single.color, AnimalBoxColor.red);
    });

    test('no animal is an empty list, not a failure', () async {
      keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
      clients[AiProvider.gemini]!.reply = '{"animals": []}';
      expect(await find(), isEmpty);
    });

    test('maps failures like the analysis does', () async {
      await expectLater(find(), failsWith(IdentificationFailure.noKey));

      keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
      clients[AiProvider.gemini]!.failure = AiVisionFailure.rateLimited;
      await expectLater(find(), failsWith(IdentificationFailure.rateLimited));

      clients[AiProvider.gemini]!
        ..failure = null
        ..reply = 'no boxes here';
      await expectLater(find(), failsWith(IdentificationFailure.badResponse));

      photos.fails = true;
      await expectLater(
        find(),
        failsWith(IdentificationFailure.unreadablePhoto),
      );
    });
  });

  test('no reference lookup when the AI suggests no species', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    clients[AiProvider.gemini]!.reply = '{"possible_species": []}';

    final result = await identify();

    expect(result.hasSpecies, isFalse);
    expect(references.asked, isEmpty);
  });
}
