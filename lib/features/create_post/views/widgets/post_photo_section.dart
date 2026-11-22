import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The post's cover photo, with a remove button at its top-right and a
/// "Change photo" button on it. Without a photo, a box that asks for one.
/// Both "Change photo" and the empty box call [onChangePhoto], which goes back
/// to the camera (where the gallery is too).
///
/// Under the cover, the extra photos, each with a remove button, and an "Add
/// photo" tile while fewer than [PostDraft.maxPhotos] are attached.
class PostPhotoSection extends StatelessWidget {
  const PostPhotoSection({
    super.key,
    required this.photoPath,
    required this.onRemove,
    required this.onChangePhoto,
    this.extraPhotoPaths = const [],
    this.freeSlots = 0,
    this.notice,
    this.onRemoveExtra,
    this.onAddPhoto,
  });

  final String? photoPath;
  final List<String> extraPhotoPaths;

  /// How many more photos fit; the "Add photo" tile shows while above 0.
  final int freeSlots;

  /// Why some picked photos were left out.
  final String? notice;

  /// Null disables the buttons (while the form is busy).
  final VoidCallback? onRemove;
  final VoidCallback? onChangePhoto;
  final ValueChanged<int>? onRemoveExtra;
  final VoidCallback? onAddPhoto;

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

    final count = 1 + extraPhotoPaths.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cover(scheme, radius),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < extraPhotoPaths.length; i++) ...[
                _ExtraPhoto(
                  path: extraPhotoPaths[i],
                  number: i + 2,
                  onRemove: onRemoveExtra == null
                      ? null
                      : () => onRemoveExtra!(i),
                ),
                const SizedBox(width: 10),
              ],
              if (freeSlots > 0) _AddPhotoTile(onTap: onAddPhoto),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$count of ${PostDraft.maxPhotos} photos. The first photo is the '
          'cover.',
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              notice!,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _cover(ColorScheme scheme, BorderRadius radius) {
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

const _thumbSize = 88.0;

/// A small extra photo with a remove button at its top-right.
class _ExtraPhoto extends StatelessWidget {
  const _ExtraPhoto({
    required this.path,
    required this.number,
    required this.onRemove,
  });

  final String path;

  /// The photo's place in the post, counting the cover as 1.
  final int number;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: _thumbSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LocalImage(
              path,
              fit: BoxFit.cover,
              semanticLabel: 'Photo $number',
              errorBuilder: (_, _, _) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _PhotoButton(
              tooltip: 'Remove photo $number',
              onPressed: onRemove,
              child: const Icon(Icons.close_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tile that adds another photo from the camera or the gallery.
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: 'Add photo',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border.all(color: scheme.outline, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: scheme.primary),
              const SizedBox(height: 4),
              Text(
                'Add photo',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
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
