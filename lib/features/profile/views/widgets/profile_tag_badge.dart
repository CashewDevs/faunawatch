import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visitors see a plain label; the owner can tap it to manage their tag.
class ProfileTagBadge extends StatelessWidget {
  const ProfileTagBadge({super.key, required this.tag, this.onTap});
  final ProfileTag tag;
  final VoidCallback? onTap;

  static IconData iconFor(ProfileTag tag) => switch (tag) {
    ProfileTag.dogLover || ProfileTag.catLover => Icons.pets_outlined,
    ProfileTag.spotter => Icons.visibility_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = Material(
      color: scheme.secondaryContainer,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(tag), size: 16, color: scheme.onSecondaryContainer),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tag.label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      label: onTap == null
          ? 'Profile tag: ${tag.label}'
          : 'Profile tag: ${tag.label}. Edit profile tag',
      button: onTap != null,
      excludeSemantics: true,
      child: onTap == null
          ? badge
          : Tooltip(
              message: 'Edit profile tag',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const StadiumBorder(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      minWidth: 44,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1,
                      child: badge,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
