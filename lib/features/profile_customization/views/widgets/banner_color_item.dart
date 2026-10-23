import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// A selectable color circle item for banner customization.
///
/// When selected, displays an outside 5pt orange border around the color swatch.
class BannerColorItem extends StatelessWidget {
  const BannerColorItem({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: isSelected
                ? Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.profileSelectedOrange,
                        width: 5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
