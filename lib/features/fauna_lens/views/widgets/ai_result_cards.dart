import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Rounded card used for the species list and the advice.
class AiResultCard extends StatelessWidget {
  const AiResultCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FaunaLensTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: child,
    );
  }
}

TextStyle aiResultTitleStyle(BuildContext context) => GoogleFonts.dmSans(
  color: FaunaLensTheme.of(context).title,
  fontSize: 15,
  fontWeight: FontWeight.w700,
);

TextStyle aiResultBodyStyle(BuildContext context) => GoogleFonts.dmSans(
  color: FaunaLensTheme.of(context).body,
  fontSize: 13,
  height: 1.35,
);

TextStyle aiResultMutedStyle(BuildContext context) => GoogleFonts.dmSans(
  color: FaunaLensTheme.of(context).muted,
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
          Text('Possible species', style: aiResultTitleStyle(context)),
          const SizedBox(height: 2),
          Text(
            result.coversSeveralAnimals
                ? 'One guess for each animal you chose. None of these is confirmed.'
                : 'Up to ${AiIdentification.maxSpecies} guesses. None of these is confirmed.',
            style: aiResultMutedStyle(context),
          ),
          const SizedBox(height: 6),
          if (!result.hasSpecies)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "The AI couldn't suggest a species for this photo. "
                'Try a closer, clearer shot.',
                style: aiResultBodyStyle(context),
              ),
            )
          else
            for (final (index, species) in result.possibleSpecies.indexed) ...[
              if (index > 0)
                const Divider(height: 1, color: AppColors.aiResultCardBorder),
              _SpeciesRow(
                rank: index + 1,
                species: species,
                showBox: result.coversSeveralAnimals,
              ),
            ],
        ],
      ),
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({
    required this.rank,
    required this.species,
    required this.showBox,
  });

  final int rank;
  final PossibleSpecies species;

  /// Several animals: the circle shows the box colour instead of a rank,
  /// since each row is a different animal rather than a weaker guess.
  final bool showBox;

  @override
  Widget build(BuildContext context) {
    final boxColor = showBox && species.boxColor != null
        ? Color(species.boxColor!.argb)
        : null;
    // With several animals every row is an equal; only one animal's guesses
    // are ranked.
    final isTop = showBox || rank == 1;
    final colors = FaunaLensTheme.of(context);
    final background = boxColor ?? (isTop ? colors.accent : colors.rank);
    final foreground = boxColor != null
        ? (boxColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
        : (isTop
              ? (colors.isDark ? AppColors.darkSurface : Colors.white)
              : colors.accent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              semanticsLabel: species.boxColor != null && showBox
                  ? '${species.boxColor!.value} box'
                  : null,
              style: GoogleFonts.dmSans(
                color: foreground,
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
                    color: colors.title,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (species.scientificName.isNotEmpty)
                  Text(
                    species.scientificName,
                    style: aiResultMutedStyle(
                      context,
                    ).copyWith(fontStyle: FontStyle.italic),
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
    final colors = FaunaLensTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.invasive,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colors.invasiveText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Possible invasive species',
                  style: aiResultTitleStyle(
                    context,
                  ).copyWith(color: colors.invasiveText),
                ),
                const SizedBox(height: 4),
                Text(
                  'The top guess appears in the pilot-area reference list. '
                  'This is a hint only, not an official classification.',
                  style: aiResultBodyStyle(
                    context,
                  ).copyWith(color: colors.invasiveText, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinted card with a small caps label, used for condition and severity.
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
    final colors = FaunaLensTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.info,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.infoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: colors.accent,
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

/// The top bar of the FaunaLens result pages: a back chevron and a
/// title on the right.
class FaunaLensPageHeader extends StatelessWidget {
  const FaunaLensPageHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = FaunaLensTheme.of(context);
    return Container(
      color: colors.header,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.aiResultBackChevron,
                  size: 34,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: colors.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
