import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiPreferences.effectiveProvider', () {
    test('uses the chosen provider even without a key', () {
      const preferences = AiPreferences(provider: AiProvider.groq);
      expect(preferences.effectiveProvider(const {}), AiProvider.groq);
    });

    test('otherwise the first provider in fallback order with a key', () {
      const preferences = AiPreferences();
      expect(
        preferences.effectiveProvider(const {
          AiProvider.groq: true,
          AiProvider.openRouter: true,
        }),
        AiProvider.openRouter,
      );
      expect(
        preferences.effectiveProvider(const {AiProvider.groq: true}),
        AiProvider.groq,
      );
    });

    test('falls back to the first provider when there are no keys', () {
      expect(
        const AiPreferences().effectiveProvider(const {}),
        AiProvider.fallbackOrder.first,
      );
    });
  });

  test('withModel sets, trims and clears one provider only', () {
    final picked = const AiPreferences(provider: AiProvider.gemini)
        .withModel(AiProvider.gemini, '  g-model ')
        .withModel(AiProvider.groq, 'q');
    expect(picked.models, {AiProvider.gemini: 'g-model', AiProvider.groq: 'q'});
    expect(picked.provider, AiProvider.gemini);

    final cleared = picked.withModel(AiProvider.gemini, null);
    expect(cleared.models, {AiProvider.groq: 'q'});
    expect(picked.withModel(AiProvider.groq, ' ').models, {
      AiProvider.gemini: 'g-model',
    });
  });

  test('withProvider keeps the chosen models', () {
    final next = const AiPreferences(
      models: {AiProvider.groq: 'q'},
    ).withProvider(AiProvider.openRouter);
    expect(next.provider, AiProvider.openRouter);
    expect(next.models, {AiProvider.groq: 'q'});
  });

  test('withBackupModel is kept apart from the main models', () {
    final picked = const AiPreferences(
      provider: AiProvider.gemini,
      models: {AiProvider.groq: 'main'},
    ).withBackupModel(AiProvider.groq, ' backup ');
    expect(picked.backupModels, {AiProvider.groq: 'backup'});
    expect(picked.models, {AiProvider.groq: 'main'});
    expect(picked.provider, AiProvider.gemini);

    // Changing the main choices keeps the backup's.
    final next = picked
        .withModel(AiProvider.groq, 'other')
        .withProvider(AiProvider.groq);
    expect(next.backupModels, {AiProvider.groq: 'backup'});

    expect(next.withBackupModel(AiProvider.groq, null).backupModels, isEmpty);
  });

  test('AiProvider.tryParse reads stored names', () {
    expect(AiProvider.tryParse('openRouter'), AiProvider.openRouter);
    expect(AiProvider.tryParse('unknown'), isNull);
    expect(AiProvider.tryParse(null), isNull);
  });
}
