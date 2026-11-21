import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The post's photo, with a remove button at its top-right and a "Change
/// photo" button on it. Without a photo, a box that asks for one. Both
/// "Change photo" and the empty box call [onChangePhoto], which goes back to
/// the camera (where the gallery is too).
class PostPhotoSection extends StatelessWidget {
  const PostPhotoSection({
    super.key,
    required this.photoPath,
    required this.onRemove,
    required this.onChangePhoto,
  });

  final String? photoPath;

  /// Null disables the buttons (while the form is busy).
  final VoidCallback? onRemove;
  final VoidCallback? onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(20);
    if (photoPath == null) {
      return Semantics(
        button: true,
        label: 'Add a photo',
        excludeSemantics: true,
        child: InkWell(
          onTap: onChangePhoto,
          borderRadius: radius,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: Border.all(color: scheme.outline, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 36,
                  color: scheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  'Add a photo',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A photo is required. 5 MB maximum.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LocalImage(
              photoPath!,
              fit: BoxFit.cover,
              semanticLabel: 'Your photo',
              errorBuilder: (_, _, _) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: const Center(child: Text('Photo preview unavailable')),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _PhotoButton(
                tooltip: 'Remove photo',
                onPressed: onRemove,
                child: const Icon(Icons.close_rounded, size: 20),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: _PhotoButton(
                onPressed: onChangePhoto,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Change photo',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

/// A dark, see-through rounded button that stays readable on any photo.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.onPressed,
    required this.child,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tooltip == null ? 14 : 8,
            vertical: 8,
          ),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: child,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
