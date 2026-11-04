import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_integration_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';

enum AiTestStatus { idle, testing, passed, failed }

/// Presentation state for the AI Integration screen.
class AiIntegrationState {
  const AiIntegrationState({
    required this.preferences,
    required this.hasKey,
    required this.defaultModels,
    this.availableModels,
    this.isLoadingModels = false,
    this.modelsFailure,
    this.testStatus = AiTestStatus.idle,
    this.testFailure,
  });

  final AiPreferences preferences;
  final Map<AiProvider, bool> hasKey;
  final Map<AiProvider, String> defaultModels;

  /// The current provider's models, or null until loaded.
  final List<AiModelOption>? availableModels;
  final bool isLoadingModels;
  final AiIntegrationFailure? modelsFailure;
  final AiTestStatus testStatus;
  final AiIntegrationFailure? testFailure;

  AiProvider get provider => preferences.effectiveProvider(hasKey);

  bool get providerHasKey => hasKey[provider] ?? false;

  /// The model in use for [provider].
  String get model => preferences.models[provider] ?? defaultModels[provider]!;

  bool get usesDefaultModel => !preferences.models.containsKey(provider);

  bool get isTesting => testStatus == AiTestStatus.testing;

  AiIntegrationState copyWith({
    AiPreferences? preferences,
    Map<AiProvider, bool>? hasKey,
    List<AiModelOption>? availableModels,
    bool clearModels = false,
    bool? isLoadingModels,
    AiIntegrationFailure? modelsFailure,
    bool clearModelsFailure = false,
    AiTestStatus? testStatus,
    AiIntegrationFailure? testFailure,
    bool clearTest = false,
  }) {
    return AiIntegrationState(
      preferences: preferences ?? this.preferences,
      hasKey: hasKey ?? this.hasKey,
      defaultModels: defaultModels,
      availableModels: clearModels
          ? null
          : availableModels ?? this.availableModels,
      isLoadingModels: isLoadingModels ?? this.isLoadingModels,
      modelsFailure: clearModels || clearModelsFailure
          ? null
          : modelsFailure ?? this.modelsFailure,
      // An explicit status wins over clearTest, so a new test can start from
      // a cleared one in a single update.
      testStatus:
          testStatus ?? (clearTest ? AiTestStatus.idle : this.testStatus),
      testFailure: clearTest ? null : testFailure ?? this.testFailure,
    );
  }
}

/// Chooses the AI provider and model, loads the provider's models and tests
/// the connection. Keys are handled entirely by the service layer.
class AiIntegrationViewModel extends AsyncNotifier<AiIntegrationState> {
  String? _userId;

  // Bumped whenever the provider or model changes, so a slow model list or
  // test for the previous choice can't overwrite the new one.
  int _generation = 0;

  AiIntegrationService get _service => ref.read(aiIntegrationServiceProvider);

  @override
  Future<AiIntegrationState> build() async {
    _generation++;
    final service = ref.watch(aiIntegrationServiceProvider);
    final userId = _userId = await ref.watch(currentUserIdProvider.future);
    return AiIntegrationState(
      preferences: userId == null
          ? const AiPreferences()
          : await ref.watch(aiPreferencesServiceProvider).load(userId),
      hasKey: userId == null ? const {} : await service.keyStatus(userId),
      defaultModels: {
        for (final provider in AiProvider.values)
          provider: service.defaultModelFor(provider),
      },
    );
  }

  Future<void> selectProvider(AiProvider provider) async {
    final current = state.valueOrNull;
    if (current == null || current.provider == provider) return;
    _generation++;
    await _savePreferences(
      current.copyWith(
        preferences: current.preferences.withProvider(provider),
        clearModels: true,
        clearTest: true,
      ),
    );
  }

  /// Picks [modelId] for the current provider, or the default when null.
  Future<void> selectModel(String? modelId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    _generation++;
    await _savePreferences(
      current.copyWith(
        preferences: current.preferences.withModel(current.provider, modelId),
        clearTest: true,
      ),
    );
  }

  /// Loads the current provider's model list.
  Future<void> loadModels() async {
    final current = state.valueOrNull;
    final userId = _userId;
    if (current == null || userId == null || current.isLoadingModels) return;
    final generation = _generation;
    state = AsyncData(
      current.copyWith(isLoadingModels: true, clearModelsFailure: true),
    );
    try {
      final models = await _service.listModels(
        userId: userId,
        provider: current.provider,
      );
      _apply(
        generation,
        (state) =>
            state.copyWith(isLoadingModels: false, availableModels: models),
      );
    } on AiIntegrationException catch (error) {
      _apply(
        generation,
        (state) => state.copyWith(
          isLoadingModels: false,
          modelsFailure: error.failure,
        ),
      );
    }
  }

  /// Sends a test photo with the current key and model.
  Future<void> testConnection() async {
    final current = state.valueOrNull;
    final userId = _userId;
    if (current == null || userId == null || current.isTesting) return;
    final generation = _generation;
    state = AsyncData(
      current.copyWith(clearTest: true, testStatus: AiTestStatus.testing),
    );
    try {
      await _service.testConnection(
        userId: userId,
        provider: current.provider,
        model: current.model,
      );
      _apply(
        generation,
        (state) => state.copyWith(testStatus: AiTestStatus.passed),
      );
    } on AiIntegrationException catch (error) {
      _apply(
        generation,
        (state) => state.copyWith(
          testStatus: AiTestStatus.failed,
          testFailure: error.failure,
        ),
      );
    }
  }

  /// Re-reads which providers have keys, e.g. after the key screen closes.
  Future<void> refreshKeys() async {
    final current = state.valueOrNull;
    final userId = _userId;
    if (current == null || userId == null) return;
    final hasKey = await _service.keyStatus(userId);
    final latest = state.valueOrNull;
    if (latest == null) return;
    final changed = AiProvider.values.any(
      (provider) => hasKey[provider] != latest.hasKey[provider],
    );
    if (!changed) return;
    _generation++;
    state = AsyncData(
      latest.copyWith(hasKey: hasKey, clearModels: true, clearTest: true),
    );
  }

  void _apply(
    int generation,
    AiIntegrationState Function(AiIntegrationState) update,
  ) {
    final latest = state.valueOrNull;
    if (generation != _generation || latest == null) return;
    state = AsyncData(update(latest));
  }

  Future<void> _savePreferences(AiIntegrationState next) async {
    state = AsyncData(next);
    final userId = _userId;
    if (userId == null) return;
    await ref.read(aiPreferencesServiceProvider).save(userId, next.preferences);
  }
}

final aiIntegrationViewModelProvider =
    AsyncNotifierProvider<AiIntegrationViewModel, AiIntegrationState>(
      AiIntegrationViewModel.new,
    );
