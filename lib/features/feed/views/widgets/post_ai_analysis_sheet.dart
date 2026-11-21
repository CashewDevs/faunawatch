import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';

/// Everything the AI suggested for a post, shown in a bottom sheet from the
/// post's "AI analysis" button. Sections without content are left out.
class PostAiAnalysisSheet extends StatelessWidget {
  const PostAiAnalysisSheet({super.key, required this.analysis});
  final PostAiAnalysis analysis;

  static Future<void> show(BuildContext context, PostAiAnalysis analysis) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (_) => PostAiAnalysisSheet(analysis: analysis),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final invasiveText = analysis.invasiveMatchName == null
        ? 'This may be an invasive species.'
        : 'This may be an invasive species: ${analysis.invasiveMatchName}.';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'AI analysis',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            FeedPost.aiNote,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (analysis.possibleInvasive) ...[
            const SizedBox(height: 16),
            _Callout(icon: Icons.warning_amber_rounded, text: invasiveText),
          ],
          if (analysis.communityWarning != null) ...[
            const SizedBox(height: 12),
            _Callout(
              icon: Icons.campaign_outlined,
              text: analysis.communityWarning!,
            ),
          ],
          if (analysis.species.isNotEmpty)
            _Section(
              title: 'Possible species',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final species in analysis.species)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: species.commonName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                children: [
                                  if (species.scientificName != null)
                                    TextSpan(
                                      text: '  ${species.scientificName}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: muted,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${species.confidence.label} confidence',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (analysis.severity != null)
            _Section(title: 'Severity', text: analysis.severity!.label),
          if (analysis.visualCondition != null)
            _Section(title: 'Condition', text: analysis.visualCondition),
          if (analysis.incidentSummary != null)
            _Section(title: 'Summary', text: analysis.incidentSummary),
          if (analysis.safetyRecommendations != null)
            _Section(title: 'What to do', text: analysis.safetyRecommendations),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.text, this.child});
  final String title;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          child ?? Text(text ?? '', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
