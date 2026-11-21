import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A still picture of the map with the observation pin, the place name under
/// it, and a button to open the full map picker. Tapping the picture opens
/// the picker too.
class LocationPreviewCard extends StatelessWidget {
  const LocationPreviewCard({
    super.key,
    required this.hasLocation,
    required this.label,
    required this.previewUrl,
    required this.onOpenMap,
  });

  final bool hasLocation;
  final String label;

  /// The picture link for a map of the given size, or null when no picture
  /// can be shown.
  final Uri? Function(int width, int height) previewUrl;

  /// Null disables the card (while the form is busy).
  final VoidCallback? onOpenMap;

  static const height = 180.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(20);
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.map_outlined, size: 40, color: scheme.outline),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: hasLocation
              ? 'Map of $label. Open the full map to adjust the pin'
              : 'Choose where you saw it on the map',
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              height: height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final url = previewUrl(
                    constraints.maxWidth.round(),
                    height.round(),
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url == null)
                        placeholder
                      else
                        Image.network(
                          url.toString(),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => placeholder,
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : placeholder,
                        ),
                      if (!hasLocation)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Tap to choose where you saw it',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(onTap: onOpenMap),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: 'Open full map',
                            onPressed: onOpenMap,
                            icon: const Icon(
                              Icons.open_in_full_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              hasLocation ? Icons.location_on : Icons.location_off_outlined,
              size: 18,
              color: hasLocation ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasLocation ? label : 'No location chosen yet',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: hasLocation ? FontWeight.w600 : FontWeight.w400,
                  color: hasLocation
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
