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

/// Stepped "Before you go exploring" walkthrough: 4 individual rule screens
/// followed by the final "Almost there" agreement screen before [IntroView].
class TermsConsentView extends ConsumerStatefulWidget {
  const TermsConsentView({super.key});

  @override
  ConsumerState<TermsConsentView> createState() => _TermsConsentViewState();
}

class _TermsConsentViewState extends ConsumerState<TermsConsentView> {
  late final PageController _pageController;

  static const _agreeGradient = [Color(0xFFD3E6B6), Color(0xFFB2EFFF)];

  @override
  void initState() {
    super.initState();
    final initialPage = ref.read(termsConsentViewModelProvider).currentPage;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateTo(int page) {
    final target = page.clamp(0, TermsConsentState.consentPageIndex);
    ref.read(termsConsentViewModelProvider.notifier).setPage(target);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleAccept() {
    if (!ref.read(termsConsentViewModelProvider.notifier).accept()) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const IntroView()));
  }

  Future<void> _handleDecline() async {
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
    if (leave == true && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(termsConsentViewModelProvider);
    final viewModel = ref.read(termsConsentViewModelProvider.notifier);

    return Scaffold(
      body: Container(
        key: const ValueKey('terms_consent_background'),
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.48, 1.0],
            colors: [
              Color.alphaBlend(
                AppColors.profileGradientTop.withValues(alpha: 0.28),
                Colors.white,
              ),
              Colors.white,
              Color.alphaBlend(
                AppColors.profileGradientBottom.withValues(alpha: 0.34),
                Colors.white,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopNavRow(
                showBack: state.currentPage > 0,
                showSkip: !state.isConsentPage,
                onBack: () => _animateTo(state.currentPage - 1),
                onSkip: () => _animateTo(TermsConsentState.consentPageIndex),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: TermsConsentState.totalPages,
                  onPageChanged: viewModel.setPage,
                  itemBuilder: (context, index) {
                    if (index < termsSections.length) {
                      return _RuleStepPage(
                        index: index,
                        section: termsSections[index],
                      );
                    }
                    return _AlmostTherePage(
                      acceptedTerms: state.acceptedTerms,
                      acknowledgedAiLimits: state.acknowledgedAiLimits,
                      onAcceptedTermsChanged: viewModel.setAcceptedTerms,
                      onAcknowledgedAiLimitsChanged:
                          viewModel.setAcknowledgedAiLimits,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepDotsIndicator(
                      currentPage: state.currentPage,
                      totalPages: TermsConsentState.totalPages,
                    ),
                    const SizedBox(height: 18),
                    if (!state.isConsentPage)
                      PillButton(
                        label: 'Next  ›',
                        primaryBorder: AppColors.loginButtonStroke,
                        primaryBorderWidth: 1.8,
                        onPressed: () => _animateTo(state.currentPage + 1),
                      )
                    else ...[
                      PillButton(
                        label: 'I agree, continue  >',
                        primaryGradientColors: _agreeGradient,
                        primaryBorder: state.canContinue
                            ? AppColors.loginButtonStroke
                            : null,
                        primaryBorderWidth: state.canContinue ? 2.0 : 1.0,
                        onPressed: state.canContinue ? _handleAccept : null,
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _handleDecline,
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

class _TopNavRow extends StatelessWidget {
  const _TopNavRow({
    required this.showBack,
    required this.showSkip,
    required this.onBack,
    required this.onSkip,
  });

  final bool showBack;
  final bool showSkip;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                tooltip: 'Previous rule',
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.consentTitleNavy,
                  size: 30,
                ),
              )
            else
              const SizedBox(width: 48),
            const Spacer(),
            if (showSkip)
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip',
                  style: GoogleFonts.dmSans(
                    color: AppColors.consentTitleNavy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _RuleVisualStyle {
  const _RuleVisualStyle({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}

const List<_RuleVisualStyle> _ruleStyles = [
  _RuleVisualStyle(
    icon: Icons.favorite_border_rounded,
    background: AppColors.consentBadgeBlueBackground,
    foreground: AppColors.consentBadgeBlueText,
  ),
  _RuleVisualStyle(
    icon: Icons.auto_awesome_outlined,
    background: AppColors.consentBadgeYellowBackground,
    foreground: AppColors.consentBadgeYellowText,
  ),
  _RuleVisualStyle(
    icon: Icons.location_on_outlined,
    background: AppColors.consentBadgeGreenBackground,
    foreground: AppColors.consentBadgeGreenText,
  ),
  _RuleVisualStyle(
    icon: Icons.shield_outlined,
    background: AppColors.consentBadgeRedBackground,
    foreground: AppColors.consentBadgeRedText,
  ),
];

class _RuleStepPage extends StatelessWidget {
  const _RuleStepPage({required this.index, required this.section});

  final int index;
  final TermsSection section;

  @override
  Widget build(BuildContext context) {
    final style = _ruleStyles[index % _ruleStyles.length];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Icon(style.icon, color: style.foreground, size: 42),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${index + 1} of ${termsSections.length}',
                style: GoogleFonts.dmSans(
                  color: style.foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              section.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.consentTitleNavy,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              section.summary,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.consentBodyText,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              section.details,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.consentBodyText,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlmostTherePage extends StatelessWidget {
  const _AlmostTherePage({
    required this.acceptedTerms,
    required this.acknowledgedAiLimits,
    required this.onAcceptedTermsChanged,
    required this.onAcknowledgedAiLimitsChanged,
  });

  final bool acceptedTerms;
  final bool acknowledgedAiLimits;
  final ValueChanged<bool> onAcceptedTermsChanged;
  final ValueChanged<bool> onAcknowledgedAiLimitsChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('almost_there_fox_badge'),
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.consentLogoBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Image.asset(AppAssets.splashFox, fit: BoxFit.contain),
            ),
            const SizedBox(height: 18),
            Text(
              'Almost there',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.consentTitleNavy,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'One last step before you explore.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.consentBodyText,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.consentCardBorder),
              ),
              child: Text(
                'v$termsVersion',
                style: GoogleFonts.dmSans(
                  color: AppColors.consentBodyText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 22),
            ConsentCheckboxRow(
              label: 'I agree to the Terms of Service and Privacy Policy.',
              value: acceptedTerms,
              onChanged: onAcceptedTermsChanged,
            ),
            const SizedBox(height: 6),
            ConsentCheckboxRow(
              label:
                  'I understand AI results are preliminary and may be wrong.',
              value: acknowledgedAiLimits,
              onChanged: onAcknowledgedAiLimitsChanged,
            ),
            const SizedBox(height: 18),
            const _AiKeysNotice(),
          ],
        ),
      ),
    );
  }
}

class _StepDotsIndicator extends StatelessWidget {
  const _StepDotsIndicator({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.consentTitleNavy
                : const Color(0xFF9DB6D8),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _AiKeysNotice extends StatelessWidget {
  const _AiKeysNotice();

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.dmSans(
      color: AppColors.consentBodyText,
      fontSize: 12.5,
      height: 1.4,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.consentInfoBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.consentCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.key_outlined,
              size: 18,
              color: AppColors.consentLogoBlue,
            ),
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
