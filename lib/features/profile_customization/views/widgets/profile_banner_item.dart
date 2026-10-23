import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// A selectable banner preset card displaying an image banner with an optional
/// 5pt outside orange border when selected.
class ProfileBannerItem extends StatelessWidget {
  const ProfileBannerItem({
    super.key,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
    this.height = 92.0,
  });

  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: AppColors.profileSelectedOrange, width: 5)
                : Border.all(color: Colors.transparent, width: 5),
          ),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}
