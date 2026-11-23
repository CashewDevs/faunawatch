import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_integration_service.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_integration_viewmodel.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_key_editor.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_model_picker_sheet.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_provider_picker_sheet.dart';

/// "AI Integration": choose the provider and model FaunaLens uses, add or
/// replace its key in a small pop-up, and test that the key and model work.
/// FaunaLens also opens it when there is no key yet.
class AiIntegrationView extends ConsumerWidget {
  const AiIntegrationView({super.key});

  static const _ready = Color(0xFF15803D);
  static const _readyDark = Color(0xFF4ADE80);

  /// Opens the key pop-up for [provider], then picks up a saved or removed
  /// key.
  Future<void> _editKey(
    BuildContext context,
    WidgetRef ref,
    AiProvider provider,
  ) async {
    await editAiProviderKey(context, ref, provider);
    await ref.read(aiIntegrationViewModelProvider.notifier).refreshKeys();
  }

  Future<void> _pickProvider(
    BuildContext context,
    WidgetRef ref,
    AiIntegrationState state,
  ) async {
    final provider = await showAiProviderPickerSheet(
      context,
      selected: state.provider,
      hasKey: state.hasKey,
    );
    if (provider != null) {
      await ref
          .read(aiIntegrationViewModelProvider.notifier)
          .selectProvider(provider);
    }
  }

  Future<void> _pickModel(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(aiIntegrationViewModelProvider.notifier);
    var state = ref.read(aiIntegrationViewModelProvider).valueOrNull;
    if (state == null) return;
    if (!state.providerHasKey) {
      await _editKey(context, ref, state.provider);
      return;
    }
    if (state.availableModels == null) {
      await viewModel.loadModels();
      state = ref.read(aiIntegrationViewModelProvider).valueOrNull;
      if (state?.availableModels == null || !context.mounted) return;
    }
    final choice = await showAiModelPickerSheet(
      context,
      provider: state!.provider,
      models: state.availableModels!,
      selected: state.model,
      defaultModel: state.defaultModels[state.provider]!,
    );
    if (choice != null) await viewModel.selectModel(choice.modelId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncState = ref.watch(aiIntegrationViewModelProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.3, 1.0],
            colors: isDark
                ? [
                    AppPaletteColors.of(context).darkProfileGradientStart,
                    AppPaletteColors.of(context).darkProfileGradientEnd,
                  ]
                : [
                    AppPaletteColors.of(context).profileBackgroundGradientStart,
                    AppPaletteColors.of(context).profileBackgroundGradientEnd,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: AppPaletteColors.of(context).shellHeaderBlue,
                        size: 32,
                      ),
                    ),
                    Text(
                      'AI Integration',
                      style: GoogleFonts.dmSans(
                        color: AppPaletteColors.of(context).shellHeaderBlue,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: asyncState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      const Center(child: Text('Could not load AI settings.')),
                  data: (state) => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      _SectionHeader('PROVIDER', isDark: isDark),
                      const SizedBox(height: 8),
                      _Card(
                        isDark: isDark,
                        children: [
                          _Row(
                            icon: Icons.auto_awesome_rounded,
                            title: 'AI provider',
                            subtitle: 'Choose the AI service.',
                            isDark: isDark,
                            below: _ProviderPill(
                              label: state.provider.displayName,
                              isDark: isDark,
                            ),
                            trailing: const Icon(Icons.arrow_forward_rounded),
                            onTap: () => _pickProvider(context, ref, state),
                          ),
                          _Row(
                            icon: Icons.key_rounded,
                            title: 'API key',
                            subtitle: state.providerHasKey
                                ? 'Configured'
                                : 'Not added. Tap to add a '
                                      '${state.provider.displayName} key.',
                            isDark: isDark,
                            onTap: () => _editKey(context, ref, state.provider),
                          ),
                          _Row(
                            icon: Icons.tune_rounded,
                            title: 'Model',
                            subtitle: state.usesDefaultModel
                                ? '${state.model} (default)'
                                : state.model,
                            isDark: isDark,
                            below: state.modelsFailure == null
                                ? (state.availableModels == null
                                      ? _Hint(
                                          'Tap refresh to load available '
                                          'models',
                                          isDark: isDark,
                                        )
                                      : null)
                                : _Hint(
                                    _failureMessage(
                                      state.modelsFailure!,
                                      state.provider,
                                      forTest: false,
                                    ),
                                    isDark: isDark,
                                    isError: true,
                                  ),
                            trailing: _RefreshButton(
                              isLoading: state.isLoadingModels,
                              onPressed: state.providerHasKey
                                  ? ref
                                        .read(
                                          aiIntegrationViewModelProvider
                                              .notifier,
                                        )
                                        .loadModels
                                  : null,
                            ),
                            onTap: state.isLoadingModels
                                ? null
                                : () => _pickModel(context, ref),
                          ),
                          _testRow(
                            title: 'Test API',
                            idle:
                                'Send a test photo to check your key and model.',
                            status: state.testStatus,
                            failure: state.testFailure,
                            provider: state.provider,
                            isDark: isDark,
                            onTap: ref
                                .read(aiIntegrationViewModelProvider.notifier)
                                .testConnection,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'FaunaLens sends your photo to this provider and '
                          'model. The test sends a small plain image, which '
                          'your provider may bill as one request.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader('BACKUP KEY', isDark: isDark),
                      const SizedBox(height: 8),
                      _Card(
                        isDark: isDark,
                        children: [
                          _Row(
                            icon: Icons.auto_awesome_outlined,
                            title: 'Backup provider',
                            subtitle: 'Choose the service for the backup key.',
                            isDark: isDark,
                            below: _ProviderPill(
                              label:
                                  state.backupProvider?.displayName ??
                                  'Not set up',
                              isDark: isDark,
                            ),
                            trailing: const Icon(Icons.arrow_forward_rounded),
                            onTap: () => _pickBackupProvider(context, ref),
                          ),
                          _Row(
                            icon: Icons.vpn_key_outlined,
                            title: 'Backup API key',
                            subtitle: state.hasBackup
                                ? 'Configured'
                                : 'Not added. Tap to add a backup key.',
                            isDark: isDark,
                            onTap: () => _editBackupKey(context, ref),
                          ),
                          if (state.hasBackup)
                            _Row(
                              icon: Icons.tune_rounded,
                              title: 'Backup model',
                              subtitle: state.usesDefaultBackupModel
                                  ? '${state.backupModel} (default)'
                                  : state.backupModel!,
                              isDark: isDark,
                              below: state.backupModelsFailure == null
                                  ? (state.backupAvailableModels == null
                                        ? _Hint(
                                            'Tap refresh to load available '
                                            'models',
                                            isDark: isDark,
                                          )
                                        : null)
                                  : _Hint(
                                      _failureMessage(
                                        state.backupModelsFailure!,
                                        state.backupProvider!,
                                        forTest: false,
                                      ),
                                      isDark: isDark,
                                      isError: true,
                                    ),
                              trailing: _RefreshButton(
                                tooltip: 'Refresh backup models',
                                isLoading: state.isLoadingBackupModels,
                                onPressed: ref
                                    .read(
                                      aiIntegrationViewModelProvider.notifier,
                                    )
                                    .loadBackupModels,
                              ),
                              onTap: state.isLoadingBackupModels
                                  ? null
                                  : () => _pickBackupModel(context, ref),
                            ),
                          if (state.hasBackup)
                            _testRow(
                              title: 'Test backup',
                              idle: 'Send a test photo with your backup key.',
                              ready: 'Backup key ready',
                              status: state.backupTestStatus,
                              failure: state.backupTestFailure,
                              provider: state.backupProvider!,
                              isDark: isDark,
                              onTap: ref
                                  .read(aiIntegrationViewModelProvider.notifier)
                                  .testBackup,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'If your main key is rejected, runs out, or its '
                          'provider is down, FaunaLens tries the backup key '
                          'once, with its own model. It can be any provider, '
                          'even a second key for the same one.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks the backup provider, then opens the key pop-up for it: a backup
  /// is only saved together with its key, so Cancel keeps the old backup.
  Future<void> _pickBackupProvider(BuildContext context, WidgetRef ref) async {
    final backup = ref
        .read(aiIntegrationViewModelProvider)
        .valueOrNull
        ?.backupProvider;
    final provider = await showAiProviderPickerSheet(
      context,
      title: 'Backup provider',
      selected: backup,
      hasKey: backup == null ? const {} : {backup: true},
    );
    if (provider == null || !context.mounted) return;
    await editAiBackupKey(context, ref, provider);
  }

  /// Opens the key pop-up for the current backup, or picks a provider first
  /// when there is none.
  Future<void> _editBackupKey(BuildContext context, WidgetRef ref) async {
    final backup = ref
        .read(aiIntegrationViewModelProvider)
        .valueOrNull
        ?.backupProvider;
    if (backup == null) return _pickBackupProvider(context, ref);
    await editAiBackupKey(context, ref, backup);
  }

  Future<void> _pickBackupModel(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(aiIntegrationViewModelProvider.notifier);
    var state = ref.read(aiIntegrationViewModelProvider).valueOrNull;
    if (state == null || !state.hasBackup) return;
    if (state.backupAvailableModels == null) {
      await viewModel.loadBackupModels();
      state = ref.read(aiIntegrationViewModelProvider).valueOrNull;
      if (state?.backupAvailableModels == null || !context.mounted) return;
    }
    final provider = state!.backupProvider!;
    final choice = await showAiModelPickerSheet(
      context,
      provider: provider,
      models: state.backupAvailableModels!,
      selected: state.backupModel!,
      defaultModel: state.defaultModels[provider]!,
    );
    if (choice != null) await viewModel.selectBackupModel(choice.modelId);
  }

  /// A row that sends a test photo and shows the result: used for both the
  /// main key ("Test API") and the backup key ("Test backup").
  static Widget _testRow({
    required String title,
    required String idle,
    String ready = 'API ready',
    required AiTestStatus status,
    required AiIntegrationFailure? failure,
    required AiProvider provider,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final resultColor = switch (status) {
      AiTestStatus.passed => isDark ? _readyDark : _ready,
      AiTestStatus.failed => AppColors.signOutButtonRed,
      _ => null,
    };
    final isTesting = status == AiTestStatus.testing;
    return _Row(
      icon: switch (status) {
        AiTestStatus.passed => Icons.check_rounded,
        AiTestStatus.failed => Icons.error_outline_rounded,
        _ => Icons.network_check_rounded,
      },
      iconColor: resultColor,
      title: title,
      subtitle: switch (status) {
        AiTestStatus.idle => idle,
        AiTestStatus.testing => 'Testing…',
        AiTestStatus.passed => ready,
        AiTestStatus.failed => _failureMessage(
          failure!,
          provider,
          forTest: true,
        ),
      },
      subtitleColor: resultColor,
      isDark: isDark,
      trailing: isTesting
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : null,
      onTap: isTesting ? null : onTap,
    );
  }

  static String _failureMessage(
    AiIntegrationFailure failure,
    AiProvider provider, {
    required bool forTest,
  }) {
    final name = provider.displayName;
    return switch (failure) {
      AiIntegrationFailure.noKey => 'Add a $name key first.',
      AiIntegrationFailure.invalidKey =>
        '$name rejected the key. Check or replace it.',
      AiIntegrationFailure.rateLimited =>
        "$name is busy or your key's limit was reached. Try again soon.",
      AiIntegrationFailure.unavailable =>
        forTest
            ? "$name or this model isn't available. Try another model."
            : "$name isn't responding. Try again later.",
      AiIntegrationFailure.network =>
        "Couldn't reach $name. Check your connection.",
      AiIntegrationFailure.badResponse =>
        forTest
            ? "This model didn't accept the test photo. Pick one that takes "
                  'images.'
            : "Couldn't read $name's model list. Try again.",
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.isDark, required this.children});

  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divider, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    this.iconColor,
    this.subtitleColor,
    this.below,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? subtitleColor;
  final Widget? below;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? AppPaletteColors.of(context).shellHeaderBlue,
              size: 26,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: subtitleColor ?? muted,
                      fontWeight: subtitleColor == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                  if (below != null) ...[const SizedBox(height: 8), below!],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              IconTheme(
                data: IconThemeData(color: muted),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderPill extends StatelessWidget {
  const _ProviderPill({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppPaletteColors.of(
                context,
              ).shellHeaderBlue.withValues(alpha: 0.2)
            : AppColors.consentBadgeBlueBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.consentBadgeBlueText,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {required this.isDark, this.isError = false});

  final String text;
  final bool isDark;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 12,
        color: isError
            ? AppColors.signOutButtonRed
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({
    required this.isLoading,
    required this.onPressed,
    this.tooltip = 'Refresh models',
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : const Icon(Icons.refresh_rounded),
    );
  }
}
