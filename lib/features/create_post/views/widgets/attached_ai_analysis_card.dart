import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';

/// Shows the FaunaLens analysis that will be saved with the post, with a
/// button to leave it out.
class AttachedAiAnalysisCard extends StatelessWidget {
  const AttachedAiAnalysisCard({
    super.key,
    required this.result,
    required this.onDetach,
  });

  final AiIdentification result;

  /// Null while the form is busy, which disables the button.
  final VoidCallback? onDetach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPaletteColors.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // A lighter, tinted card with an accent outline, so the analysis stands
    // out from the form in both light and dark mode.
    final accent = isDark
        ? palette.darkAccentBlue
        : palette.resolve(AppColors.faunaLensBlue, theme.colorScheme.primary);
    final background = isDark
        ? const Color(0xFF233552)
        : palette.resolve(
            AppColors.aiResultInfoBackground,
            theme.colorScheme.primaryContainer,
          );
    final invasive = result.invasiveMatch;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: isDark ? AppColors.faunaLensYellow : accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FaunaLens AI analysis will be saved with this post',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.speciesSummary ?? 'No animal identified',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text('Category: ${result.category.label}'),
            const SizedBox(height: 4),
            Text('Severity: ${result.severity.label}'),
            if (invasive != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Possible invasive species: ${invasive.commonName}',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Preliminary AI-assisted suggestions. AI can be wrong, and '
              'moderators review them with your post.',
              style: theme.textTheme.bodySmall,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onDetach,
                style: TextButton.styleFrom(foregroundColor: accent),
                icon: const Icon(Icons.link_off),
                label: const Text("Don't attach analysis"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
