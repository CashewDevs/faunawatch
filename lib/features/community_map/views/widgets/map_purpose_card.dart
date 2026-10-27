import 'package:flutter/material.dart';

/// Explains the map before community report layers are connected.
class MapPurposeCard extends StatelessWidget {
  const MapPurposeCard({
    super.key,
    required this.onLearnMore,
    required this.onDismiss,
  });

  final VoidCallback onLearnMore;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MAP PREVIEW',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Dismiss map preview',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Wildlife encounters, on one shared map',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'See where wildlife is reported, understand each incident, '
                      'and stay aware of nearby activity.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Try the Cebu City warning demo. The sample pin, zones, and '
                      'position are simulated; live reports and GPS warnings are still in development.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: onLearnMore,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('How this map works'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
