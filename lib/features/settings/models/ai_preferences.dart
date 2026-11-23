import 'package:faunawatch/features/settings/models/ai_provider.dart';

/// Which AI provider and model the user chose. Not secret: keys are stored
/// separately.
class AiPreferences {
  const AiPreferences({
    this.provider,
    this.models = const {},
    this.backupModels = const {},
  });

  /// The provider the user picked, or null if they haven't.
  final AiProvider? provider;

  /// The model picked for each provider. Missing means the default.
  final Map<AiProvider, String> models;

  /// The model picked for the backup key, per provider, apart from [models].
  /// Kept per provider so switching the backup provider never carries over a
  /// model the new provider doesn't have. Missing means the default.
  final Map<AiProvider, String> backupModels;

  /// The provider to use: the chosen one, otherwise the first in
  /// [AiProvider.fallbackOrder] with a key, otherwise the first in that order.
  AiProvider effectiveProvider(Map<AiProvider, bool> hasKey) {
    if (provider != null) return provider!;
    for (final candidate in AiProvider.fallbackOrder) {
      if (hasKey[candidate] ?? false) return candidate;
    }
    return AiProvider.fallbackOrder.first;
  }

  AiPreferences withProvider(AiProvider provider) => AiPreferences(
    provider: provider,
    models: models,
    backupModels: backupModels,
  );

  /// Sets [model] for [provider], or goes back to the default when null.
  AiPreferences withModel(AiProvider provider, String? model) => AiPreferences(
    provider: this.provider,
    models: _withEntry(models, provider, model),
    backupModels: backupModels,
  );

  /// Sets the backup key's [model] for [provider], or goes back to the
  /// default when null.
  AiPreferences withBackupModel(AiProvider provider, String? model) =>
      AiPreferences(
        provider: this.provider,
        models: models,
        backupModels: _withEntry(backupModels, provider, model),
      );

  static Map<AiProvider, String> _withEntry(
    Map<AiProvider, String> from,
    AiProvider provider,
    String? model,
  ) {
    final next = Map<AiProvider, String>.of(from);
    if (model == null || model.trim().isEmpty) {
      next.remove(provider);
    } else {
      next[provider] = model.trim();
    }
    return next;
  }
}
