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
    this.backupProvider,
    this.backupAvailableModels,
    this.isLoadingBackupModels = false,
    this.backupModelsFailure,
    this.backupTestStatus = AiTestStatus.idle,
    this.backupTestFailure,
  });

  final AiPreferences preferences;
  final Map<AiProvider, bool> hasKey;
  final Map<AiProvider, String> defaultModels;

  /// The backup key's provider, or null when there is no backup key.
  final AiProvider? backupProvider;

  /// The backup provider's models (listed with the backup key), or null
  /// until loaded.
  final List<AiModelOption>? backupAvailableModels;
  final bool isLoadingBackupModels;
  final AiIntegrationFailure? backupModelsFailure;
  final AiTestStatus backupTestStatus;
  final AiIntegrationFailure? backupTestFailure;

  bool get hasBackup => backupProvider != null;

  /// The model the backup uses: the backup's own choice for its provider,
  /// else that provider's default.
  String? get backupModel => backupProvider == null
      ? null
      : preferences.backupModels[backupProvider] ??
            defaultModels[backupProvider]!;

  bool get usesDefaultBackupModel =>
      backupProvider != null &&
      !preferences.backupModels.containsKey(backupProvider);

  bool get isTestingBackup => backupTestStatus == AiTestStatus.testing;

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
    AiProvider? backupProvider,
    bool clearBackup = false,
    List<AiModelOption>? backupAvailableModels,
    bool clearBackupModels = false,
    bool? isLoadingBackupModels,
    AiIntegrationFailure? backupModelsFailure,
    bool clearBackupModelsFailure = false,
    AiTestStatus? backupTestStatus,
    AiIntegrationFailure? backupTestFailure,
    bool clearBackupTest = false,
  }) {
    final resetBackupTest = clearBackup || clearBackupTest;
    final resetBackupModels = clearBackup || clearBackupModels;
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
      backupProvider: clearBackup
          ? null
          : backupProvider ?? this.backupProvider,
      backupAvailableModels: resetBackupModels
          ? null
          : backupAvailableModels ?? this.backupAvailableModels,
      isLoadingBackupModels:
          isLoadingBackupModels ??
          (resetBackupModels ? false : this.isLoadingBackupModels),
      backupModelsFailure: resetBackupModels || clearBackupModelsFailure
          ? null
          : backupModelsFailure ?? this.backupModelsFailure,
      backupTestStatus:
          backupTestStatus ??
          (resetBackupTest ? AiTestStatus.idle : this.backupTestStatus),
      backupTestFailure: resetBackupTest
          ? null
          : backupTestFailure ?? this.backupTestFailure,
    );
  }
}

/// Chooses the AI provider and model, loads the provider's models and tests
/// the connection; does the same for the backup key, and saves or removes
/// it. Keys are read only by the service layer.
class AiIntegrationViewModel extends AsyncNotifier<AiIntegrationState> {
  String? _userId;

  // Bumped whenever the provider or model changes, so a slow model list or
  // test for the previous choice can't overwrite the new one.
  int _generation = 0;

  // Bumped whenever the backup key or its model changes, so a slow backup
  // model list or test can't report on the previous one.
  int _backupGeneration = 0;

  AiIntegrationService get _service => ref.read(aiIntegrationServiceProvider);

  @override
  Future<AiIntegrationState> build() async {
    _generation++;
    _backupGeneration++;
    final service = ref.watch(aiIntegrationServiceProvider);
    final userId = _userId = await ref.watch(currentUserIdProvider.future);
    return AiIntegrationState(
      preferences: userId == null
          ? const AiPreferences()
          : await ref.watch(aiPreferencesServiceProvider).load(userId),
      hasKey: userId == null ? const {} : await service.keyStatus(userId),
      backupProvider: userId == null
          ? null
          : await service.backupProvider(userId),
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

  /// Saves [apiKey] for [provider] as the backup key, replacing any earlier
  /// one. Returns whether it was saved.
  Future<bool> saveBackupKey(AiProvider provider, String apiKey) async {
    final userId = _userId;
    if (userId == null) return false;
    try {
      await _service.saveBackupKey(
        userId: userId,
        provider: provider,
        apiKey: apiKey,
      );
    } on Object {
      return false;
    }
    _backupChanged(
      (state) => state.copyWith(
        backupProvider: provider,
        clearBackupModels: true,
        clearBackupTest: true,
      ),
    );
    return true;
  }

  /// Deletes the backup key. Returns whether it was removed.
  Future<bool> removeBackupKey() async {
    final userId = _userId;
    if (userId == null) return false;
    try {
      await _service.removeBackupKey(userId);
    } on Object {
      return false;
    }
    _backupChanged((state) => state.copyWith(clearBackup: true));
    return true;
  }

  /// Picks [modelId] for the backup key, or its provider's default when null.
  Future<void> selectBackupModel(String? modelId) async {
    final current = state.valueOrNull;
    final provider = current?.backupProvider;
    if (current == null || provider == null) return;
    _backupGeneration++;
    await _savePreferences(
      current.copyWith(
        preferences: current.preferences.withBackupModel(provider, modelId),
        clearBackupTest: true,
      ),
    );
  }

  /// Loads the backup provider's model list, asked with the backup key.
  Future<void> loadBackupModels() async {
    final current = state.valueOrNull;
    final userId = _userId;
    if (current == null ||
        userId == null ||
        !current.hasBackup ||
        current.isLoadingBackupModels) {
      return;
    }
    final generation = _backupGeneration;
    state = AsyncData(
      current.copyWith(
        isLoadingBackupModels: true,
        clearBackupModelsFailure: true,
      ),
    );
    try {
      final models = await _service.listBackupModels(userId);
      _applyBackup(
        generation,
        (state) => state.copyWith(
          isLoadingBackupModels: false,
          backupAvailableModels: models,
        ),
      );
    } on AiIntegrationException catch (error) {
      _applyBackup(
        generation,
        (state) => state.copyWith(
          isLoadingBackupModels: false,
          backupModelsFailure: error.failure,
        ),
      );
    }
  }

  /// Sends a test photo with the backup key and its model.
  Future<void> testBackup() async {
    final current = state.valueOrNull;
    final userId = _userId;
    final model = current?.backupModel;
    if (current == null ||
        userId == null ||
        model == null ||
        current.isTestingBackup) {
      return;
    }
    final generation = _backupGeneration;
    state = AsyncData(
      current.copyWith(
        clearBackupTest: true,
        backupTestStatus: AiTestStatus.testing,
      ),
    );
    try {
      await _service.testBackup(userId: userId, model: model);
      _applyBackup(
        generation,
        (state) => state.copyWith(backupTestStatus: AiTestStatus.passed),
      );
    } on AiIntegrationException catch (error) {
      _applyBackup(
        generation,
        (state) => state.copyWith(
          backupTestStatus: AiTestStatus.failed,
          backupTestFailure: error.failure,
        ),
      );
    }
  }

  /// Re-reads which providers have keys and the backup key, e.g. after a key
  /// pop-up closes.
  Future<void> refreshKeys() async {
    final current = state.valueOrNull;
    final userId = _userId;
    if (current == null || userId == null) return;
    final hasKey = await _service.keyStatus(userId);
    final backupProvider = await _service.backupProvider(userId);
    var latest = state.valueOrNull;
    if (latest == null) return;
    if (backupProvider != latest.backupProvider) {
      // The backup was added, replaced or removed elsewhere: its old model
      // list and test result no longer apply.
      _backupGeneration++;
      latest = latest.copyWith(
        backupProvider: backupProvider,
        clearBackup: backupProvider == null,
        clearBackupModels: true,
        clearBackupTest: true,
      );
      state = AsyncData(latest);
    }
    final changed = AiProvider.values.any(
      (provider) => hasKey[provider] != latest!.hasKey[provider],
    );
    if (!changed) return;
    _generation++;
    state = AsyncData(
      latest.copyWith(hasKey: hasKey, clearModels: true, clearTest: true),
    );
  }

  /// A new or removed backup key makes any loading model list or running
  /// test about the old one, so those are dropped.
  void _backupChanged(AiIntegrationState Function(AiIntegrationState) update) {
    _backupGeneration++;
    final latest = state.valueOrNull;
    if (latest != null) state = AsyncData(update(latest));
  }

  void _applyBackup(
    int generation,
    AiIntegrationState Function(AiIntegrationState) update,
  ) {
    final latest = state.valueOrNull;
    if (generation != _backupGeneration || latest == null) return;
    state = AsyncData(update(latest));
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
