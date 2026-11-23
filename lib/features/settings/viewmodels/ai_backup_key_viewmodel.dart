import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

class AiBackupKeyState {
  const AiBackupKeyState({
    this.backupProvider,
    this.isSaving = false,
    this.errorMessage,
  });

  /// The saved backup's provider, or null when there is none.
  final AiProvider? backupProvider;
  final bool isSaving;
  final String? errorMessage;

  bool get hasBackup => backupProvider != null;
}

/// Settings › AI Integration › Backup key: saves, replaces or removes the
/// one backup key. The key goes straight to secure storage and is never kept
/// in this state.
class AiBackupKeyViewModel extends AutoDisposeAsyncNotifier<AiBackupKeyState> {
  String? _userId;

  AiBackupKeyStorageService get _storage =>
      ref.read(aiBackupKeyStorageServiceProvider);

  @override
  Future<AiBackupKeyState> build() async {
    final userId = _userId = await ref.watch(currentUserIdProvider.future);
    if (userId == null) return const AiBackupKeyState();
    return AiBackupKeyState(
      backupProvider: await ref
          .watch(aiBackupKeyStorageServiceProvider)
          .readProvider(userId),
    );
  }

  /// Blocks screenshots while the key screen is visible.
  Future<void> enableWindowSecurity() =>
      ref.read(windowSecurityServiceProvider).enableSecure();

  Future<void> disableWindowSecurity() =>
      ref.read(windowSecurityServiceProvider).disableSecure();

  /// Opens a provider page (key console or terms) outside the app.
  Future<bool> openExternalLink(Uri uri) =>
      ref.read(externalLinkServiceProvider).open(uri);

  /// Saves [apiKey] for [provider] as the backup, replacing any earlier one.
  Future<bool> save(AiProvider provider, String apiKey) => _change(
    () => _storage.save(_userId!, provider, apiKey),
    provider,
    'Could not save the backup key. Please try again.',
  );

  Future<bool> remove() => _change(
    () => _storage.delete(_userId!),
    null,
    'Could not remove the backup key. Please try again.',
  );

  Future<bool> _change(
    Future<void> Function() write,
    AiProvider? backupAfter,
    String failureMessage,
  ) async {
    final current = state.valueOrNull;
    if (current == null || current.isSaving) return false;
    if (_userId == null) {
      state = AsyncData(
        AiBackupKeyState(
          backupProvider: current.backupProvider,
          errorMessage: 'Sign in to save keys.',
        ),
      );
      return false;
    }
    state = AsyncData(
      AiBackupKeyState(backupProvider: current.backupProvider, isSaving: true),
    );
    try {
      await write();
      state = AsyncData(AiBackupKeyState(backupProvider: backupAfter));
      return true;
    } on Object {
      state = AsyncData(
        AiBackupKeyState(
          backupProvider: current.backupProvider,
          errorMessage: failureMessage,
        ),
      );
      return false;
    }
  }
}

final aiBackupKeyViewModelProvider =
    AsyncNotifierProvider.autoDispose<AiBackupKeyViewModel, AiBackupKeyState>(
      AiBackupKeyViewModel.new,
    );
