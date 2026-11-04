import 'dart:typed_data';

import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_integration_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';

const _user = 'user-a';

void main() {
  late FakeKeyStorage keys;
  late Map<AiProvider, FakeVisionClient> clients;
  late AiIntegrationService service;

  setUp(() {
    keys = FakeKeyStorage();
    clients = {
      for (final provider in AiProvider.values)
        provider: FakeVisionClient(defaultModel: '${provider.name}-default'),
    };
    service = AiIntegrationService(
      keys: keys,
      clients: clients,
      testImage: () async => Uint8List.fromList([9]),
    );
  });

  Matcher failsWith(AiIntegrationFailure failure) => throwsA(
    isA<AiIntegrationException>().having((e) => e.failure, 'failure', failure),
  );

  test('reports which providers have a key', () async {
    keys.keys[(_user, AiProvider.groq)] = 'k';
    keys.keys[('someone-else', AiProvider.gemini)] = 'k';

    expect(await service.keyStatus(_user), {
      AiProvider.gemini: false,
      AiProvider.groq: true,
      AiProvider.openRouter: false,
    });
  });

  test('gives each provider\'s default model', () {
    expect(service.defaultModelFor(AiProvider.groq), 'groq-default');
  });

  test('lists models with the saved key', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';

    final models = await service.listModels(
      userId: _user,
      provider: AiProvider.gemini,
    );

    expect(models.single.id, 'listed-model');
    expect(clients[AiProvider.gemini]!.keysUsed, ['gemini-key']);
  });

  test('needs a key to list models or test', () async {
    await expectLater(
      service.listModels(userId: _user, provider: AiProvider.groq),
      failsWith(AiIntegrationFailure.noKey),
    );
    await expectLater(
      service.testConnection(
        userId: _user,
        provider: AiProvider.groq,
        model: 'm',
      ),
      failsWith(AiIntegrationFailure.noKey),
    );
    expect(clients[AiProvider.groq]!.keysUsed, isEmpty);
  });

  test('the test sends a photo to the chosen model', () async {
    keys.keys[(_user, AiProvider.openRouter)] = 'or-key';

    await service.testConnection(
      userId: _user,
      provider: AiProvider.openRouter,
      model: 'picked/model',
    );

    final client = clients[AiProvider.openRouter]!;
    expect(client.keysUsed, ['or-key']);
    expect(client.modelsUsed, ['picked/model']);
    expect(client.mimeTypes, ['image/png']);
  });

  test('maps provider failures', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    const expected = {
      AiVisionFailure.invalidKey: AiIntegrationFailure.invalidKey,
      AiVisionFailure.rateLimited: AiIntegrationFailure.rateLimited,
      AiVisionFailure.unavailable: AiIntegrationFailure.unavailable,
      AiVisionFailure.network: AiIntegrationFailure.network,
      AiVisionFailure.badResponse: AiIntegrationFailure.badResponse,
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      clients[AiProvider.gemini]!.failure = key;
      await expectLater(
        service.testConnection(
          userId: _user,
          provider: AiProvider.gemini,
          model: 'm',
        ),
        failsWith(value),
      );
      await expectLater(
        service.listModels(userId: _user, provider: AiProvider.gemini),
        failsWith(value),
      );
    }
  });

  testWidgets('the built-in test image is a real PNG', (tester) async {
    keys.keys[(_user, AiProvider.gemini)] = 'gemini-key';
    final real = AiIntegrationService(keys: keys, clients: clients);

    await tester.runAsync(
      () => real.testConnection(
        userId: _user,
        provider: AiProvider.gemini,
        model: 'm',
      ),
    );

    final client = clients[AiProvider.gemini]!;
    expect(client.mimeTypes, ['image/png']);
    expect(client.imagesSent.single.take(4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
