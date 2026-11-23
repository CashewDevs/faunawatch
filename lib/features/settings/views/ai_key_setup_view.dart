import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_integration_viewmodel.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_key_editor.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_provider_picker_sheet.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_settings_card.dart';
import 'package:faunawatch/features/terms/views/terms_consent_view.dart';

/// "Power up FaunaLens": onboarding step after profile setup where the user
/// picks an AI provider and adds their own key, in the same card style as
/// Settings › AI Integration. The key is typed in the key pop-up and saved
/// only after the AI Keys Agreement for that provider.
///
/// Always light, like the onboarding screens around it, even in dark mode.
/// The model and the connection test stay in Settings › AI Integration.
class AiKeySetupView extends ConsumerWidget {
  const AiKeySetupView({super.key});

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

  Future<void> _editKey(
    BuildContext context,
    WidgetRef ref,
    AiProvider provider,
  ) async {
    // Removing a key is left to Settings; here a wrong key is replaced.
    await editAiProviderKey(context, ref, provider, allowRemove: false);
    await ref.read(aiIntegrationViewModelProvider.notifier).refreshKeys();
  }

  void _goToTerms(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TermsConsentView()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _buildScreen(context, ref);
    }
    // The screen is built from a context inside the light theme, so the
    // pop-ups and sheets it opens are light too.
    return Theme(
      data: ref.watch(appLightThemeProvider),
      child: Builder(builder: (context) => _buildScreen(context, ref)),
    );
  }

  Widget _buildScreen(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(aiIntegrationViewModelProvider);
    final state = asyncState.valueOrNull;
    final hasSavedKey = state?.hasKey.values.any((saved) => saved) ?? false;

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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  children: [
                    const _KeyBadge(),
                    const SizedBox(height: 16),
                    Text(
                      'Power up FaunaLens',
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
                        'Add your own AI key so FaunaLens can identify the '
                        'animals you spot. You only need one.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: AppColors.consentBodyText,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...asyncState.when(
                      loading: () => const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                      error: (_, _) => const [
                        Center(child: Text('Could not load AI settings.')),
                      ],
                      data: (state) => _buildKeyCard(context, ref, state),
                    ),
                    const SizedBox(height: 16),
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
                child: Column(
                  children: [
                    PillButton(
                      label: 'Continue  >',
                      onPressed: hasSavedKey ? () => _goToTerms(context) : null,
                    ),
                    const SizedBox(height: 12),
                    PillButton(
                      label: 'Set up later',
                      isPrimary: false,
                      onPressed: () => _goToTerms(context),
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

  List<Widget> _buildKeyCard(
    BuildContext context,
    WidgetRef ref,
    AiIntegrationState state,
  ) {
    const isDark = false;
    return [
      const AiSettingsSectionHeader('YOUR AI KEY', isDark: isDark),
      const SizedBox(height: 8),
      AiSettingsCard(
        isDark: isDark,
        children: [
          AiSettingsRow(
            icon: Icons.auto_awesome_rounded,
            title: 'AI provider',
            subtitle: 'Choose the AI service.',
            isDark: isDark,
            below: AiProviderPill(
              label: state.provider.displayName,
              isDark: isDark,
            ),
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: () => _pickProvider(context, ref, state),
          ),
          AiSettingsRow(
            icon: Icons.key_rounded,
            title: 'API key',
            subtitle: state.providerHasKey
                ? 'Configured'
                : 'Not added. Tap to add a '
                      '${state.provider.displayName} key.',
            isDark: isDark,
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: () => _editKey(context, ref, state.provider),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'FaunaLens uses the default model. You can pick another and test '
          'your key later in Settings › AI Integration.',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
    ];
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
