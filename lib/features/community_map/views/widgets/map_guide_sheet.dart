import 'package:flutter/material.dart';

/// Describes the planned report-to-map flow without suggesting it is live.
class MapGuideSheet extends StatelessWidget {
  const MapGuideSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'How this map works',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close map guide',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'FaunaWatch connects wildlife reports with community awareness. '
              'The Cebu City sample pin, warning zones, and blue position marker '
              'are a demo, not real wildlife reports or your GPS location.',
            ),
            const SizedBox(height: 24),
            const Text(
              'Try the warning demo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Close the preview card with X, then select Approaching, Near, '
              'or Danger Zone. The blue marker moves into the matching sample zone. '
              'Yellow, orange, and red zones use demo radii of 900 m, 500 m, '
              'and 180 m; these are not the final warning thresholds.',
            ),
            const SizedBox(height: 24),
            const _GuideStep(
              icon: Icons.location_on_outlined,
              title: 'Find reported encounters',
              description:
                  'Approved reports will appear as pins at approximate '
                  'locations. Nearby reports can be grouped to make busy areas easier to explore.',
            ),
            const SizedBox(height: 20),
            const _GuideStep(
              icon: Icons.pets_outlined,
              title: 'Understand the incident',
              description:
                  'Pins will open species suggestions and incident details: '
                  'an animal in need, a potentially dangerous animal, a possible '
                  'invasive species, or another wildlife incident. AI assessments are preliminary.',
            ),
            const SizedBox(height: 20),
            const _GuideStep(
              icon: Icons.notifications_active_outlined,
              title: 'Stay aware of nearby activity',
              description:
                  'Planned proximity warnings use three levels: '
                  'Approaching, Near, and Danger Zone. They are intended to help '
                  'you understand nearby reports and act with caution.',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Try it now: tap the red pin to preview a sample post and see more in the feed. Drag to explore, pinch to zoom, rotate with '
                      'two fingers, and use the 2D/3D button to change perspective.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
          child: Icon(icon, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
