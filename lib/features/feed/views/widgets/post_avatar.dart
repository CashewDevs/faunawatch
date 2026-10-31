import 'dart:io';
import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Circular profile picture from a local file, URL, or asset, in that order.
/// Falls back to a person icon.
class PostAvatar extends StatelessWidget {
  const PostAvatar({
    super.key,
    required this.size,
    this.asset,
    this.filePath,
    this.url,
  });

  final double size;
  final String? asset;
  final String? filePath;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.messagesPfpPlaceholder,
      child: Icon(Icons.person, color: Colors.white, size: size * 0.65),
    );
    Widget errorBuilder(BuildContext _, Object _, StackTrace? _) => fallback;

    final Widget image;
    if (filePath != null) {
      image = Image.file(
        File(filePath!),
        fit: BoxFit.cover,
        errorBuilder: errorBuilder,
      );
    } else if (url != null) {
      image = Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: errorBuilder,
      );
    } else if (asset != null) {
      image = Image.asset(
        asset!,
        fit: BoxFit.cover,
        errorBuilder: errorBuilder,
      );
    } else {
      image = fallback;
    }
    return SizedBox.square(
      dimension: size,
      child: ClipOval(child: image),
    );
  }
}
