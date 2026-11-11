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
    final guess = result.topGuess;
    final invasive = result.invasiveMatch;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FaunaLens AI analysis will be saved with this post',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              guess == null ? 'No animal identified' : guess.displayName,
              style: theme.textTheme.bodyLarge,
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
