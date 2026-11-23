import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_backup_key_viewmodel.dart';
import 'package:faunawatch/features/settings/views/ai_key_setup_view.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_keys_agreement_sheet.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_provider_key_card.dart';

/// Settings › AI Integration › Backup key: one extra key, for any provider,
/// that FaunaLens tries when the main key fails. Looks and behaves like
/// "Your AI keys": the same provider cards, the AI Keys Agreement before
/// saving, and screenshots blocked while it is open.
class AiBackupKeyView extends ConsumerStatefulWidget {
  const AiBackupKeyView({super.key});

  @override
  ConsumerState<AiBackupKeyView> createState() => _AiBackupKeyViewState();
}

class _AiBackupKeyViewState extends ConsumerState<AiBackupKeyView> {
  final _controllers = {
    for (final provider in AiProvider.values) provider: TextEditingController(),
  };
  late final AiBackupKeyViewModel _viewModel;
  AiProvider? _expandedProvider;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(aiBackupKeyViewModelProvider.notifier);
    _viewModel.enableWindowSecurity();
  }

  @override
  void dispose() {
    _viewModel.disableWindowSecurity();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleProvider(AiProvider provider) {
    setState(() {
      _expandedProvider = _expandedProvider == provider ? null : provider;
      _obscureKey = true;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLink(Uri uri) async {
    final opened = await _viewModel.openExternalLink(uri);
    if (!opened && mounted) {
      _showMessage("Couldn't open the link. Please try again.");
    }
  }

  String _errorOr(String fallback) =>
      ref.read(aiBackupKeyViewModelProvider).valueOrNull?.errorMessage ??
      fallback;

  /// Asks for agreement, then saves the typed key for [provider] as the
  /// backup (replacing any earlier backup).
  Future<bool> _save(AiProvider provider) async {
    final controller = _controllers[provider]!;
    if (controller.text.trim().isEmpty) return false;

    FocusScope.of(context).unfocus();
    final agreed = await showAiKeysAgreementSheet(
      context,
      provider: provider,
      onReadFullAgreement: () => showAiKeysFullAgreement(
        context,
        provider: provider,
        onOpenTerms: () => _openLink(provider.termsUri),
      ),
    );
    if (!agreed || !mounted) return false;

    final saved = await _viewModel.save(provider, controller.text);
    if (!mounted) return saved;
    if (saved) {
      setState(() {
        for (final other in _controllers.values) {
          other.clear();
        }
        _obscureKey = true;
      });
      _showMessage('${provider.displayName} backup key saved.');
    } else {
      _showMessage(_errorOr('Could not save the backup key.'));
    }
    return saved;
  }

  Future<void> _remove(AiProvider provider) async {
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove backup key?'),
        content: Text(
          'FaunaLens will only use your main key. Your '
          '${provider.displayName} backup key is deleted from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final removed = await _viewModel.remove();
    if (!mounted) return;
    if (removed) {
      setState(() => _controllers[provider]!.clear());
      _showMessage('Backup key removed.');
    } else {
      _showMessage(_errorOr('Could not remove the backup key.'));
    }
  }

  /// Saves a typed but unsaved key (the first card with one), then closes.
  Future<void> _handleDone() async {
    for (final provider in AiKeySetupView.providers) {
      if (_controllers[provider]!.text.trim().isEmpty) continue;
      setState(() => _expandedProvider = provider);
      if (!await _save(provider) || !mounted) return;
      break;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(aiBackupKeyViewModelProvider);
    final state = async.valueOrNull;
    final isSaving = state?.isSaving ?? false;
    final backup = state?.backupProvider;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.profileGradientTop,
              AppColors.profileGradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: isSaving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.consentTitleNavy,
                          size: 32,
                        ),
                      ),
                    ),
                    Text(
                      'Backup key',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: AppColors.consentTitleNavy,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'If your main key is rejected, runs out, or its '
                        'provider is down, FaunaLens tries this key once. '
                        'Pick any provider, even a second key for the same '
                        'one.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: AppColors.consentBodyText,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...async.when(
                      loading: () => const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                      error: (_, _) => const [
                        Center(
                          child: Text('Could not load secure key settings.'),
                        ),
                      ],
                      data: (state) => [
                        for (final provider in AiKeySetupView.providers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AiProviderKeyCard(
                              provider: provider,
                              isConfigured: state.backupProvider == provider,
                              isExpanded: _expandedProvider == provider,
                              controller: _controllers[provider]!,
                              obscureKey: _obscureKey,
                              enabled: !state.isSaving,
                              onToggle: () => _toggleProvider(provider),
                              onToggleObscure: () =>
                                  setState(() => _obscureKey = !_obscureKey),
                              onKeyChanged: (_) => setState(() {}),
                              onSubmitted: () => _save(provider),
                              onGetKey: () => _openLink(provider.keyConsoleUri),
                              onRemove: () => _remove(provider),
                            ),
                          ),
                        if (backup != null &&
                            _expandedProvider != null &&
                            _expandedProvider != backup)
                          Padding(
                            key: const ValueKey('backup_replace_note'),
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            child: Text(
                              'Saving a ${_expandedProvider!.displayName} key '
                              'replaces your ${backup.displayName} backup key.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                color: AppColors.consentBodyText,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: AppColors.consentMutedText,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Keys are encrypted and stay on this phone.',
                            style: GoogleFonts.dmSans(
                              color: AppColors.consentMutedText,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: PillButton(
                  label: 'Done',
                  isLoading: isSaving,
                  onPressed: isSaving ? null : _handleDone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
