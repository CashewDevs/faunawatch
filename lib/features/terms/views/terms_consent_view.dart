import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/intro/views/intro_view.dart';
import 'package:faunawatch/features/terms/models/terms_section.dart';
import 'package:faunawatch/features/terms/viewmodels/terms_consent_viewmodel.dart';
import 'package:faunawatch/features/terms/views/widgets/consent_checkbox_row.dart';
import 'package:faunawatch/features/terms/views/widgets/terms_section_tile.dart';

/// "Before you go exploring": the short-form terms the user must accept
/// after adding AI keys, before the welcome intro.
class TermsConsentView extends ConsumerWidget {
  const TermsConsentView({super.key});

  void _handleAccept(BuildContext context, WidgetRef ref) {
    if (!ref.read(termsConsentViewModelProvider.notifier).accept()) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const IntroView()));
  }

  Future<void> _handleDecline(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agreement needed'),
        content: const Text(
          'FaunaWatch can only be used after agreeing to these terms. '
          'You can come back and review them anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Review terms'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(termsConsentViewModelProvider);
    final viewModel = ref.read(termsConsentViewModelProvider.notifier);

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
              const SizedBox(height: 24),
              const _TermsHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _TermsSectionsCard(
                        expandedSection: state.expandedSection,
                        onToggle: viewModel.toggleSection,
                      ),
                      const SizedBox(height: 12),
                      const _AiKeysNotice(),
                      const SizedBox(height: 8),
                      ConsentCheckboxRow(
                        label:
                            'I agree to the Terms of Service and Privacy Policy.',
                        value: state.acceptedTerms,
                        onChanged: viewModel.setAcceptedTerms,
                      ),
                      ConsentCheckboxRow(
                        label:
                            'I understand AI results are preliminary and may '
                            'be wrong.',
                        value: state.acknowledgedAiLimits,
                        onChanged: viewModel.setAcknowledgedAiLimits,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Column(
                  children: [
                    PillButton(
                      label: 'I agree, continue  >',
                      onPressed: state.canContinue
                          ? () => _handleAccept(context, ref)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _handleDecline(context),
                      child: Text(
                        'Decline',
                        style: GoogleFonts.dmSans(
                          color: AppColors.consentTitleNavy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _TermsHeader extends StatelessWidget {
  const _TermsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.consentLogoBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Image.asset(AppAssets.appLogo, fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          Text(
            'Before you go exploring',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: AppColors.consentTitleNavy,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "The short version of what you're agreeing to. Tap a section to "
            'read more.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: AppColors.consentBodyText,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Last updated $termsLastUpdated · v$termsVersion',
              style: GoogleFonts.dmSans(
                color: AppColors.consentBodyText,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSectionsCard extends StatelessWidget {
  const _TermsSectionsCard({
    required this.expandedSection,
    required this.onToggle,
  });

  final int? expandedSection;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < termsSections.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.consentCardBorder,
                ),
              TermsSectionTile(
                number: i + 1,
                section: termsSections[i],
                isExpanded: expandedSection == i,
                onTap: () => onToggle(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiKeysNotice extends StatelessWidget {
  const _AiKeysNotice();

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.dmSans(
      color: AppColors.consentBodyText,
      fontSize: 12,
      height: 1.4,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.consentInfoBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.consentCardBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.key_outlined,
            size: 18,
            color: AppColors.consentLogoBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: style,
                children: const [
                  TextSpan(text: "Using your own AI keys? You'll see a short "),
                  TextSpan(
                    text: 'AI Keys Agreement',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.consentTitleNavy,
                    ),
                  ),
                  TextSpan(text: ' when you add one.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
