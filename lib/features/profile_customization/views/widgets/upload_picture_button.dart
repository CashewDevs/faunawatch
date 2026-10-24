import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Circular upload button allowing users to pick a custom photo with orange selection border.
class UploadPictureButton extends StatelessWidget {
  const UploadPictureButton({
    super.key,
    required this.isSelected,
    required this.customImagePath,
    required this.onTap,
  });

  final bool isSelected;
  final String? customImagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: AppColors.profileSelectedOrange, width: 5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child:
                  customImagePath != null &&
                      customImagePath!.isNotEmpty &&
                      !kIsWeb
                  ? Image.file(File(customImagePath!), fit: BoxFit.cover)
                  : Center(
                      child: Image.asset(
                        AppAssets.uploadIcon,
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
