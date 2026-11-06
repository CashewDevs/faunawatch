import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// White rounded card used for the species list and the advice.
class AiResultCard extends StatelessWidget {
  const AiResultCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.aiResultCardBorder),
      ),
      child: child,
    );
  }
}

TextStyle aiResultTitleStyle() => GoogleFonts.dmSans(
  color: AppColors.consentTitleNavy,
  fontSize: 15,
  fontWeight: FontWeight.w700,
);

TextStyle aiResultBodyStyle() => GoogleFonts.dmSans(
  color: AppColors.consentBodyText,
  fontSize: 13,
  height: 1.35,
);

TextStyle aiResultMutedStyle() => GoogleFonts.dmSans(
  color: AppColors.consentMutedText,
  fontSize: 11.5,
  height: 1.3,
);

/// "Possible species": up to three ranked guesses with their confidence.
class PossibleSpeciesCard extends StatelessWidget {
  const PossibleSpeciesCard({super.key, required this.result});

  final AiIdentification result;

  @override
  Widget build(BuildContext context) {
    return AiResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Possible species', style: aiResultTitleStyle()),
          const SizedBox(height: 2),
          Text(
            'Up to ${AiIdentification.maxSpecies} guesses. None of these is confirmed.',
            style: aiResultMutedStyle(),
          ),
          const SizedBox(height: 6),
          if (!result.hasSpecies)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "The AI couldn't suggest a species for this photo. "
                'Try a closer, clearer shot.',
                style: aiResultBodyStyle(),
              ),
            )
          else
            for (final (index, species) in result.possibleSpecies.indexed) ...[
              if (index > 0)
                const Divider(height: 1, color: AppColors.aiResultCardBorder),
              _SpeciesRow(rank: index + 1, species: species),
            ],
        ],
      ),
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({required this.rank, required this.species});

  final int rank;
  final PossibleSpecies species;

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop
                  ? AppColors.faunaLensBlue
                  : AppColors.aiResultRankBackground,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: GoogleFonts.dmSans(
                color: isTop ? Colors.white : AppColors.faunaLensBlue,
                fontSize: 12,
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
                  species.commonName,
                  style: GoogleFonts.dmSans(
                    color: AppColors.consentTitleNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (species.scientificName.isNotEmpty)
                  Text(
                    species.scientificName,
                    style: aiResultMutedStyle().copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConfidenceChip(confidence: species.confidence),
        ],
      ),
    );
  }
}

/// Small rounded label for a confidence level.
class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip({super.key, required this.confidence});

  final SpeciesConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final (background, text) = switch (confidence) {
      SpeciesConfidence.high => (
        AppColors.consentBadgeGreenBackground,
        AppColors.consentBadgeGreenText,
      ),
      SpeciesConfidence.medium => (
        AppColors.consentBadgeYellowBackground,
        AppColors.consentBadgeYellowText,
      ),
      SpeciesConfidence.low => (
        AppColors.consentBadgeBlueBackground,
        AppColors.consentBadgeBlueText,
      ),
      SpeciesConfidence.uncertain => (
        AppColors.consentInfoBackground,
        AppColors.consentMutedText,
      ),
    };
    return _Pill(label: confidence.label, background: background, text: text);
  }
}

/// Small rounded label for a severity level.
class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.severity});

  final SeverityLevel severity;

  @override
  Widget build(BuildContext context) {
    final (background, text) = switch (severity) {
      SeverityLevel.low => (
        AppColors.consentBadgeGreenBackground,
        AppColors.consentBadgeGreenText,
      ),
      SeverityLevel.moderate => (
        AppColors.consentBadgeYellowBackground,
        AppColors.consentBadgeYellowText,
      ),
      SeverityLevel.high || SeverityLevel.critical => (
        AppColors.consentBadgeRedBackground,
        AppColors.consentBadgeRedText,
      ),
      SeverityLevel.uncertain => (
        AppColors.consentInfoBackground,
        AppColors.consentMutedText,
      ),
    };
    return _Pill(label: severity.label, background: background, text: text);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.text,
  });

  final String label;
  final Color background;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Peach warning shown only when the top guess matches the invasive
/// reference list.
class InvasiveHintCard extends StatelessWidget {
  const InvasiveHintCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.aiResultInvasiveBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.aiResultInvasiveText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Possible invasive species',
                  style: aiResultTitleStyle().copyWith(
                    color: AppColors.aiResultInvasiveText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The top guess appears in the pilot-area reference list. '
                  'This is a hint only, not an official classification.',
                  style: aiResultBodyStyle().copyWith(
                    color: AppColors.aiResultInvasiveText,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Light blue card with a small caps label, used for condition and severity.
class AiResultInfoCard extends StatelessWidget {
  const AiResultInfoCard({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.aiResultInfoBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.aiResultInfoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppColors.faunaLensBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}
