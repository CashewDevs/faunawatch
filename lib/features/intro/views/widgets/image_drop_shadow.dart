import 'dart:ui';
import 'package:flutter/material.dart';

/// Renders an asset image with a customized silhouette drop shadow.
///
/// Designed to support transparent WebP/PNG assets where a standard [BoxShadow]
/// would otherwise create a rectangular shadow box instead of following the
/// graphic's alpha silhouette.
class ImageDropShadow extends StatelessWidget {
  const ImageDropShadow({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.offset = const Offset(0, 4),
    this.blurRadius = 4.0,
    this.shadowColor = const Color(0x40000000), // #000000 at 25% opacity
  });

  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Offset offset;
  final double blurRadius;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Drop shadow silhouette
        Transform.translate(
          offset: offset,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blurRadius,
              sigmaY: blurRadius,
              tileMode: TileMode.decal,
            ),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(shadowColor, BlendMode.srcIn),
              child: Image.asset(
                imagePath,
                width: width,
                height: height,
                fit: fit,
              ),
            ),
          ),
        ),
        // Foreground image
        Image.asset(imagePath, width: width, height: height, fit: fit),
      ],
    );
  }
}
