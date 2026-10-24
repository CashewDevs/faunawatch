import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Circular avatar item displaying a spotter icon with a 5pt outside orange border when selected.
class SpotterAvatarItem extends StatelessWidget {
  const SpotterAvatarItem({
    super.key,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: AppColors.profileSelectedOrange, width: 5)
              : null,
        ),
        padding: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: ClipOval(child: Image.asset(assetPath, fit: BoxFit.cover)),
      ),
    );
  }
}
