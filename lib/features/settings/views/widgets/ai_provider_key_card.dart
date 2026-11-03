import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';

/// Expandable card for one AI provider: status pill when collapsed, key
/// field and "where do I get a key" link when expanded.
class AiProviderKeyCard extends StatelessWidget {
  const AiProviderKeyCard({
    super.key,
    required this.provider,
    required this.isConfigured,
    required this.isExpanded,
    required this.controller,
    required this.obscureKey,
    required this.enabled,
    required this.onToggle,
    required this.onToggleObscure,
    required this.onKeyChanged,
    required this.onSubmitted,
    required this.onGetKey,
  });

  final AiProvider provider;
  final bool isConfigured;
  final bool isExpanded;
  final TextEditingController controller;
  final bool obscureKey;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onKeyChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onGetKey;

  static (Color, Color) badgeColors(AiProvider provider) => switch (provider) {
    AiProvider.openRouter => (
      AppColors.consentBadgeBlueBackground,
      AppColors.consentBadgeBlueText,
    ),
    AiProvider.groq => (
      AppColors.consentBadgeYellowBackground,
      AppColors.consentBadgeYellowText,
    ),
    AiProvider.gemini => (
      AppColors.searchHeaderBackground,
      AppColors.consentLogoBlue,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (badgeBackground, badgeText) = badgeColors(provider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? AppColors.aiKeyActiveBorder
              : AppColors.consentCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: isExpanded,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          provider.monogram,
                          style: GoogleFonts.dmSans(
                            color: badgeText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.displayName,
                              style: GoogleFonts.dmSans(
                                color: AppColors.consentTitleNavy,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              provider.tagline,
                              style: GoogleFonts.dmSans(
                                color: AppColors.consentMutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(isConfigured: isConfigured),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.consentBadgeBlueText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? _buildKeyField(context)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${provider.displayName} API key',
            style: GoogleFonts.dmSans(
              color: AppColors.consentTitleNavy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureKey,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onChanged: onKeyChanged,
            onSubmitted: (_) => onSubmitted(),
            style: GoogleFonts.dmSans(
              color: AppColors.consentTitleNavy,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              // A saved key is never read back; dots only signal one exists.
              hintText: isConfigured ? '•' * 28 : provider.keyHint,
              hintStyle: GoogleFonts.dmSans(
                color: AppColors.consentMutedText,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.aiKeyFieldBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.consentCardBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.consentCardBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.aiKeyActiveBorder,
                  width: 1.5,
                ),
              ),
              suffixIcon: IconButton(
                tooltip: obscureKey ? 'Show API key' : 'Hide API key',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.consentLogoBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onGetKey,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Where do I get a ${provider.displayName} key?',
                      style: GoogleFonts.dmSans(
                        color: AppColors.consentLinkBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.north_east_rounded,
                    size: 14,
                    color: AppColors.consentLinkBlue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isConfigured});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isConfigured
            ? AppColors.aiKeyAddedBackground
            : AppColors.aiKeyMissingBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isConfigured ? 'Key added' : 'Add key',
        style: GoogleFonts.dmSans(
          color: isConfigured
              ? AppColors.aiKeyAddedText
              : AppColors.aiKeyMissingText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
