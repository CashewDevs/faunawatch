import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/terms/models/terms_section.dart';

/// A numbered, expandable summary row on the terms consent screen.
class TermsSectionTile extends StatelessWidget {
  const TermsSectionTile({
    super.key,
    required this.number,
    required this.section,
    required this.isExpanded,
    required this.onTap,
  });

  final int number;
  final TermsSection section;
  final bool isExpanded;
  final VoidCallback onTap;

  static const _badgeColors = [
    (AppColors.consentBadgeBlueBackground, AppColors.consentBadgeBlueText),
    (AppColors.consentBadgeYellowBackground, AppColors.consentBadgeYellowText),
    (AppColors.consentBadgeGreenBackground, AppColors.consentBadgeGreenText),
    (AppColors.consentBadgeRedBackground, AppColors.consentBadgeRedText),
  ];

  @override
  Widget build(BuildContext context) {
    final (badgeBackground, badgeText) =
        _badgeColors[(number - 1) % _badgeColors.length];

    return Semantics(
      button: true,
      expanded: isExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        color: isExpanded
            ? AppColors.consentExpandedBackground
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badgeBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$number',
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
                            section.title,
                            style: GoogleFonts.dmSans(
                              color: AppColors.consentTitleNavy,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            section.summary,
                            style: GoogleFonts.dmSans(
                              color: AppColors.consentMutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: isExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(left: 44, top: 10),
                          child: Text(
                            section.details,
                            style: GoogleFonts.dmSans(
                              color: AppColors.consentBodyText,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
