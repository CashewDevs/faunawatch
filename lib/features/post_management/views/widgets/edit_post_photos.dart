import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:faunawatch/features/post_management/models/edit_post_state.dart';

/// The photos on Edit post, in order: the first is marked "Cover". Each has a
/// remove button; the others can be made the cover. An "Add photo" tile
/// shows while fewer than 3 photos are there.
class EditPostPhotos extends StatelessWidget {
  const EditPostPhotos({
    super.key,
    required this.photos,
    required this.freeSlots,
    this.notice,
    this.onRemove,
    this.onMakeCover,
    this.onAdd,
  });

  final List<EditablePhoto> photos;
  final int freeSlots;

  /// Why some picked photos were left out, or another photo problem.
  final String? notice;

  /// Null disables the buttons (while saving).
  final ValueChanged<int>? onRemove, onMakeCover;
  final VoidCallback? onAdd;

  static const _size = 104.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Photos',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < photos.length; i++)
              _PhotoTile(
                photo: photos[i],
                isCover: i == 0,
                size: _size,
                onRemove: onRemove == null ? null : () => onRemove!(i),
                onMakeCover: i == 0 || onMakeCover == null
                    ? null
                    : () => onMakeCover!(i),
              ),
            if (freeSlots > 0) _AddTile(size: _size, onTap: onAdd),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          photos.isEmpty
              ? 'A post needs at least one photo.'
              : '${photos.length} of ${EditPostState.maxPhotos} photos. The '
                    'first photo is the cover.',
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            color: photos.isEmpty ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
        if (notice case final notice?) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              notice,
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
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.isCover,
    required this.size,
    this.onRemove,
    this.onMakeCover,
  });

  final EditablePhoto photo;
  final bool isCover;
  final double size;
  final VoidCallback? onRemove, onMakeCover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined)),
    );
    final image = switch (photo) {
      ExistingPhoto(:final url?) => Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
      ExistingPhoto() => placeholder,
      NewPhoto(:final path) => LocalImage(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    };
    return Semantics(
      label: isCover ? 'Cover photo' : 'Photo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              Positioned(
                top: 4,
                right: 4,
                child: _RoundButton(
                  tooltip: isCover ? 'Remove cover photo' : 'Remove photo',
                  onPressed: onRemove,
                  child: const Icon(Icons.close_rounded, size: 16),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: isCover
                    ? const _Label(text: 'Cover')
                    : _RoundButton(
                        tooltip: 'Make cover',
                        onPressed: onMakeCover,
                        child: const Text(
                          'Make cover',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.size, this.onTap});
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Add photo',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                'Add photo',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
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
