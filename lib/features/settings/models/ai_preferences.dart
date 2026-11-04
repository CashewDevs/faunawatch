import 'package:faunawatch/features/settings/models/ai_provider.dart';

/// Which AI provider and model the user chose. Not secret: keys are stored
/// separately.
class AiPreferences {
  const AiPreferences({this.provider, this.models = const {}});

  /// The provider the user picked, or null if they haven't.
  final AiProvider? provider;

  /// The model picked for each provider. Missing means the default.
  final Map<AiProvider, String> models;

  /// The provider to use: the chosen one, otherwise the first in
  /// [AiProvider.fallbackOrder] with a key, otherwise the first in that order.
  AiProvider effectiveProvider(Map<AiProvider, bool> hasKey) {
    if (provider != null) return provider!;
    for (final candidate in AiProvider.fallbackOrder) {
      if (hasKey[candidate] ?? false) return candidate;
    }
    return AiProvider.fallbackOrder.first;
  }

  AiPreferences withProvider(AiProvider provider) =>
      AiPreferences(provider: provider, models: models);

  /// Sets [model] for [provider], or goes back to the default when null.
  AiPreferences withModel(AiProvider provider, String? model) {
    final next = Map<AiProvider, String>.of(models);
    if (model == null || model.trim().isEmpty) {
      next.remove(provider);
    } else {
      next[provider] = model.trim();
    }
    return AiPreferences(provider: this.provider, models: next);
  }
}
