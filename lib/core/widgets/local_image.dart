import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a photo from a path returned by the image picker or camera.
///
/// On the web those paths are blob URLs rather than files, and [Image.file]
/// throws there, so they load as network images instead.
class LocalImage extends StatelessWidget {
  const LocalImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.semanticLabel,
    this.errorBuilder,
    this.frameBuilder,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final String? semanticLabel;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageFrameBuilder? frameBuilder;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: errorBuilder,
        frameBuilder: frameBuilder,
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: errorBuilder,
      frameBuilder: frameBuilder,
    );
  }
}
