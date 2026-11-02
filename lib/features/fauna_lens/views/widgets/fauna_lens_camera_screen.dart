import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Live viewfinder with the close, flash, gallery, shutter, and switch controls.
class FaunaLensCameraScreen extends StatelessWidget {
  const FaunaLensCameraScreen({
    super.key,
    required this.state,
    required this.previewController,
    required this.onClose,
    required this.onToggleFlash,
    required this.onPickFromGallery,
    required this.onCapture,
    required this.onSwitchLens,
    required this.onRetryCamera,
  });

  final FaunaLensState state;
  final CameraController? previewController;
  final VoidCallback onClose;
  final VoidCallback onToggleFlash;
  final VoidCallback onPickFromGallery;
  final VoidCallback onCapture;
  final VoidCallback onSwitchLens;
  final VoidCallback onRetryCamera;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final isUnavailable =
        state.cameraStatus == FaunaLensCameraStatus.unavailable;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.faunaLensBar,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Preview(controller: previewController),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      math.max(45, topInset + 8),
                      24,
                      0,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _TopButton(
                              label: 'Close camera',
                              icon: Icons.close_rounded,
                              iconSize: 24,
                              onTap: onClose,
                            ),
                            _TopButton(
                              label: state.isFlashOn
                                  ? 'Turn flash off'
                                  : 'Turn flash on',
                              icon: Icons.flash_on,
                              iconSize: 26,
                              iconColor: state.isFlashOn
                                  ? AppColors.faunaLensYellow
                                  : Colors.white,
                              onTap: onToggleFlash,
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        const _SafetyBanner(),
                        Expanded(
                          child: isUnavailable
                              ? _CameraUnavailable(onRetry: onRetryCamera)
                              : const _ViewfinderGuide(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _ControlBar(
              isBusy: state.isBusy,
              onPickFromGallery: onPickFromGallery,
              onCapture: onCapture,
              onSwitchLens: onSwitchLens,
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});

  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final previewSize = controller?.value.previewSize;
    if (controller == null || previewSize == null) {
      return const ColoredBox(color: AppColors.faunaLensPreviewPlaceholder);
    }
    // The plugin reports its size in landscape, so the sides are swapped to
    // fill the portrait viewfinder without stretching the image.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({
    required this.label,
    required this.icon,
    required this.iconSize,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final String label;
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.faunaLensBar.withValues(alpha: 0.75),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 10, 13),
      decoration: BoxDecoration(
        color: AppColors.faunaLensBlue.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Fills the icon's cut-out exclamation mark, which would
              // otherwise show the banner's blue through it.
              Container(
                width: 3,
                height: 11,
                margin: const EdgeInsets.only(top: 3),
                color: AppColors.faunaLensNoticeText,
              ),
              const Icon(
                Icons.warning_rounded,
                color: AppColors.faunaLensYellow,
                size: 24,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Stay at a safe distance. Never approach or handle the animal to get a photo.',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderGuide extends StatelessWidget {
  const _ViewfinderGuide();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 56),
        Flexible(
          flex: 281,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: const AspectRatio(
                  aspectRatio: 280 / 281,
                  child: FaunaLensFrameCorners(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Fit the whole animal inside the frame.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(flex: 115),
      ],
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Can't open the camera. Check that FaunaWatch has camera "
              'permission in your device settings, or choose a photo from '
              'your gallery.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.isBusy,
    required this.onPickFromGallery,
    required this.onCapture,
    required this.onSwitchLens,
  });

  final bool isBusy;
  final VoidCallback onPickFromGallery;
  final VoidCallback onCapture;
  final VoidCallback onSwitchLens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.faunaLensBar,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 169,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 50,
          children: [
            _SideButton(
              label: 'Choose from gallery',
              shape: BoxShape.rectangle,
              onTap: onPickFromGallery,
              child: const FaunaLensPictureIcon(
                size: 32,
                color: AppColors.faunaLensYellow,
                background: AppColors.faunaLensBlue,
              ),
            ),
            _Shutter(isBusy: isBusy, onTap: onCapture),
            _SideButton(
              label: 'Switch camera',
              shape: BoxShape.circle,
              onTap: onSwitchLens,
              child: const Icon(
                Icons.cached_rounded,
                color: AppColors.faunaLensYellow,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.shape,
    required this.onTap,
    required this.child,
  });

  final String label;
  final BoxShape shape;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 53,
          height: 53,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.faunaLensBlue,
            shape: shape,
            borderRadius: shape == BoxShape.rectangle
                ? BorderRadius.circular(10)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.isBusy, required this.onTap});

  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: isBusy ? 0.6 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.faunaLensYellow, width: 5),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.faunaLensYellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
