import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

class AiKeySettingsState {
  const AiKeySettingsState({
    this.selectedProvider = AiProvider.gemini,
    this.configuredProviders = const {},
    this.isSaving = false,
    this.errorMessage,
  });

  final AiProvider selectedProvider;
  final Map<AiProvider, bool> configuredProviders;
  final bool isSaving;
  final String? errorMessage;

  bool get selectedProviderIsConfigured =>
      configuredProviders[selectedProvider] ?? false;

  AiKeySettingsState copyWith({
    AiProvider? selectedProvider,
    Map<AiProvider, bool>? configuredProviders,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AiKeySettingsState(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      configuredProviders: configuredProviders ?? this.configuredProviders,
      isSaving: isSaving ?? this.isSaving,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AiKeySettingsViewModel extends AsyncNotifier<AiKeySettingsState> {
  @override
  Future<AiKeySettingsState> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const AiKeySettingsState();
    }
    final storage = ref.watch(aiApiKeyStorageServiceProvider);
    final configuredProviders = <AiProvider, bool>{};
    for (final provider in AiProvider.values) {
      configuredProviders[provider] =
          await storage.readKey(userId, provider) != null;
    }
    return AiKeySettingsState(configuredProviders: configuredProviders);
  }

  void selectProvider(AiProvider provider) {
    final current = state.asData?.value;
    if (current == null || current.isSaving) return;
    state = AsyncData(
      current.copyWith(selectedProvider: provider, clearErrorMessage: true),
    );
  }

  Future<bool> saveKey(String apiKey) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      state = AsyncData(
        (state.asData?.value ?? const AiKeySettingsState()).copyWith(
          errorMessage: 'User must be signed in to save keys.',
        ),
      );
      return false;
    }

    final current = state.asData?.value;
    if (current == null || current.isSaving) return false;
    state = AsyncData(current.copyWith(isSaving: true, clearErrorMessage: true));

    try {
      await ref
          .read(aiApiKeyStorageServiceProvider)
          .saveKey(userId, current.selectedProvider, apiKey);
      final configuredProviders = Map<AiProvider, bool>.from(
        current.configuredProviders,
      )..[current.selectedProvider] = true;
      state = AsyncData(
        current.copyWith(
          configuredProviders: configuredProviders,
          isSaving: false,
          clearErrorMessage: true,
        ),
      );
      return true;
    } on Object {
      state = AsyncData(
        current.copyWith(
          isSaving: false,
          errorMessage: 'Could not save the key. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> removeKey() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;

    final current = state.asData?.value;
    if (current == null || current.isSaving) return false;
    state = AsyncData(current.copyWith(isSaving: true, clearErrorMessage: true));

    try {
      await ref
          .read(aiApiKeyStorageServiceProvider)
          .deleteKey(userId, current.selectedProvider);
      final configuredProviders = Map<AiProvider, bool>.from(
        current.configuredProviders,
      )..[current.selectedProvider] = false;
      state = AsyncData(
        current.copyWith(
          configuredProviders: configuredProviders,
          isSaving: false,
          clearErrorMessage: true,
        ),
      );
      return true;
    } on Object {
      state = AsyncData(
        current.copyWith(
          isSaving: false,
          errorMessage: 'Could not remove the key. Please try again.',
        ),
      );
      return false;
    }
  }

  /// Deletes all AI provider keys for the user.
  ///
  /// Intended to be called on sign-out.
  Future<void> deleteAllKeys([String? userId]) async {
    final targetUserId = userId ?? ref.read(currentUserIdProvider);
    if (targetUserId == null) return;
    await ref.read(aiApiKeyStorageServiceProvider).deleteAllKeys(targetUserId);
    ref.invalidateSelf();
  }
}

final aiKeySettingsViewModelProvider =
    AsyncNotifierProvider<AiKeySettingsViewModel, AiKeySettingsState>(
  AiKeySettingsViewModel.new,
);