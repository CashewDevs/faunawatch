import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';

class MapWarningDemoCard extends StatelessWidget {
  const MapWarningDemoCard({
    super.key,
    required this.level,
    required this.onSelect,
    required this.onRecenter,
    required this.onDismiss,
    required this.hasError,
  });

  final DemoWarningLevel level;
  final ValueChanged<DemoWarningLevel> onSelect;
  final VoidCallback onRecenter;
  final VoidCallback onDismiss;
  final bool hasError;

  Color _color(DemoWarningLevel level) => switch (level) {
    DemoWarningLevel.approaching => const Color(0xFFFACC15),
    DemoWarningLevel.near => const Color(0xFFFB923C),
    DemoWarningLevel.danger => const Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cebu City · Demo only',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRecenter,
                  tooltip: hasError
                      ? 'Retry warning demo'
                      : 'Recenter Cebu City demo',
                  icon: Icon(
                    hasError ? Icons.refresh : Icons.center_focus_strong,
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Collapse warning demo',
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
                    if (hasError)
                      const Text(
                        'Unable to draw the demo. Tap retry to try again.',
                      )
                    else
                      Text(
                        '${level.label} · ${level.sampleDistanceMeters.toInt()} m away (simulated)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final option in DemoWarningLevel.values)
                          ChoiceChip(
                            label: Text(option.label),
                            avatar: Icon(
                              Icons.circle,
                              color: _color(option),
                              size: 12,
                            ),
                            showCheckmark: false,
                            selected: option == level,
                            onSelected: (_) => onSelect(option),
                            tooltip:
                                'Sample ${option.label} zone: ${option.radiusMeters.toInt()} m',
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select a level to move the blue marker. Sample radii: '
                      '900 / 500 / 180 m. No live GPS or real incident.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
