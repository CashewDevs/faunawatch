import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_key_settings_viewmodel.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_keys_agreement_sheet.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_provider_key_card.dart';
import 'package:faunawatch/features/terms/views/terms_consent_view.dart';

/// "Power up FaunaLens": onboarding step after profile setup where the user
/// adds their own AI provider key. Every key is saved only after accepting
/// the AI Keys Agreement for that provider.
///
/// [AiKeySetupView.manage] opens the same screen from the profile so the user
/// can add, replace or remove keys later (e.g. after choosing "Set up later").
class AiKeySetupView extends ConsumerStatefulWidget {
  const AiKeySetupView({super.key}) : isManaging = false;

  /// Profile entry point: back button and "Done" instead of the onboarding
  /// Continue / Set up later actions, plus removing saved keys.
  const AiKeySetupView.manage({super.key}) : isManaging = true;

  final bool isManaging;

  /// Display order of the provider cards.
  static const providers = [
    AiProvider.openRouter,
    AiProvider.groq,
    AiProvider.gemini,
  ];

  @override
  ConsumerState<AiKeySetupView> createState() => _AiKeySetupViewState();
}

class _AiKeySetupViewState extends ConsumerState<AiKeySetupView> {
  final _controllers = {
    for (final provider in AiProvider.values) provider: TextEditingController(),
  };
  late final AiKeySettingsViewModel _viewModel;
  AiProvider? _expandedProvider;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(aiKeySettingsViewModelProvider.notifier);
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

  AiProvider? get _providerWithDraft {
    for (final provider in AiKeySetupView.providers) {
      if (_controllers[provider]!.text.trim().isNotEmpty) return provider;
    }
    return null;
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

  void _showFullAgreement(AiProvider provider) {
    // TODO(legal): Link the full AI Keys Agreement document once it is
    // published. Until then this shows the complete in-app agreement text.
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI Keys Agreement'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (_, title, body) in aiKeysAgreementPoints(
                provider,
              )) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: body),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _openLink(provider.termsUri),
            child: Text('${provider.displayName} terms'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Asks for agreement, then saves the typed key for [provider].
  Future<bool> _saveDraft(AiProvider provider) async {
    final controller = _controllers[provider]!;
    if (controller.text.trim().isEmpty) return false;

    FocusScope.of(context).unfocus();
    final agreed = await showAiKeysAgreementSheet(
      context,
      provider: provider,
      onReadFullAgreement: () => _showFullAgreement(provider),
    );
    if (!agreed || !mounted) return false;

    _viewModel.selectProvider(provider);
    final saved = await _viewModel.saveKey(controller.text);
    if (!mounted) return saved;

    if (saved) {
      setState(() {
        controller.clear();
        _obscureKey = true;
      });
      _showMessage('${provider.displayName} key saved.');
    } else {
      _showMessage(
        ref.read(aiKeySettingsViewModelProvider).asData?.value.errorMessage ??
            'Could not save the key. Please try again.',
      );
    }
    return saved;
  }

  Future<void> _removeKey(AiProvider provider) async {
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${provider.displayName} key?'),
        content: const Text(
          "FaunaLens won't be able to use this provider until you add a "
          'key again.',
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

    _viewModel.selectProvider(provider);
    final removed = await _viewModel.removeKey();
    if (!mounted) return;
    if (removed) {
      setState(() {
        _controllers[provider]!.clear();
        _obscureKey = true;
      });
      _showMessage('${provider.displayName} key removed.');
    } else {
      _showMessage(
        ref.read(aiKeySettingsViewModelProvider).asData?.value.errorMessage ??
            'Could not remove the key. Please try again.',
      );
    }
  }

  /// Saves every typed but unsaved key, one agreement per provider, in card
  /// order. Stops at the first one that is declined or fails, so the keys
  /// still typed stay on screen. Returns true when none is left unsaved.
  Future<bool> _savePendingDrafts() async {
    for (final provider in AiKeySetupView.providers) {
      if (_controllers[provider]!.text.trim().isEmpty) continue;
      setState(() => _expandedProvider = provider);
      if (!await _saveDraft(provider) || !mounted) return false;
    }
    return true;
  }

  Future<void> _handleContinue() async {
    if (!await _savePendingDrafts()) return;
    if (mounted) await _goToTerms();
  }

  Future<void> _handleDone() async {
    if (!await _savePendingDrafts()) return;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _goToTerms() async {
    // The following screens never show keys, so lift the screenshot block
    // while they are on top and restore it if the user comes back.
    await _viewModel.disableWindowSecurity();
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TermsConsentView()));
    if (mounted) await _viewModel.enableWindowSecurity();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(aiKeySettingsViewModelProvider);
    final settings = settingsAsync.asData?.value;
    final isSaving = settings?.isSaving ?? false;
    final hasSavedKey =
        settings?.configuredProviders.values.any((saved) => saved) ?? false;
    final canContinue =
        !isSaving && (hasSavedKey || _providerWithDraft != null);
    final isManaging = widget.isManaging;

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
                    if (isManaging)
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
                    const _KeyBadge(),
                    const SizedBox(height: 16),
                    Text(
                      isManaging ? 'Your AI keys' : 'Power up FaunaLens',
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
                        isManaging
                            ? 'Add, replace or remove the keys FaunaLens uses '
                                  'to identify animals. You only need one.'
                            : 'Add your own AI key so FaunaLens can identify '
                                  'the animals you spot. You only need one.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: AppColors.consentBodyText,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...settingsAsync.when(
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
                      data: (settings) => [
                        for (final provider in AiKeySetupView.providers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AiProviderKeyCard(
                              provider: provider,
                              isConfigured:
                                  settings.configuredProviders[provider] ??
                                  false,
                              isExpanded: _expandedProvider == provider,
                              controller: _controllers[provider]!,
                              obscureKey: _obscureKey,
                              enabled: !settings.isSaving,
                              onToggle: () => _toggleProvider(provider),
                              onToggleObscure: () =>
                                  setState(() => _obscureKey = !_obscureKey),
                              onKeyChanged: (_) => setState(() {}),
                              onSubmitted: () => _saveDraft(provider),
                              onGetKey: () => _openLink(provider.keyConsoleUri),
                              onRemove: isManaging
                                  ? () => _removeKey(provider)
                                  : null,
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
                child: isManaging
                    ? PillButton(
                        label: 'Done',
                        isLoading: isSaving,
                        onPressed: isSaving ? null : _handleDone,
                      )
                    : Column(
                        children: [
                          PillButton(
                            label: 'Continue  >',
                            isLoading: isSaving,
                            onPressed: canContinue ? _handleContinue : null,
                          ),
                          const SizedBox(height: 12),
                          PillButton(
                            label: 'Set up later',
                            isPrimary: false,
                            onPressed: isSaving ? null : _goToTerms,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yellow key medallion with a few spark rays, drawn without image assets.
class _KeyBadge extends StatelessWidget {
  const _KeyBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final angle in const [-2.4, -2.0, -1.6])
              Transform.translate(
                offset: Offset(math.cos(angle) * 44, math.sin(angle) * 44),
                child: Transform.rotate(
                  angle: angle + math.pi / 2,
                  child: Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.consentLogoBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.aiKeyIconYellow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: const Icon(
                  Icons.key_rounded,
                  size: 40,
                  color: AppColors.consentLogoBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
