import 'dart:math' as math;

import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_icons.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows a captured or selected photo and asks what to do with it.
class FaunaLensReviewScreen extends StatelessWidget {
  const FaunaLensReviewScreen({
    super.key,
    required this.photo,
    required this.onBack,
    required this.onAskAi,
    required this.onChangePhoto,
    required this.onSkipAi,
  });

  final FaunaLensPhoto photo;
  final VoidCallback onBack;
  final VoidCallback onAskAi;

  /// Retakes the photo, or picks another one if it came from the gallery.
  final VoidCallback onChangePhoto;
  final VoidCallback onSkipAi;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final colors = FaunaLensTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.statusBar,
      child: Scaffold(
        backgroundColor: colors.reviewTop,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                42,
                math.max(35, topInset + 8),
                37,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BackButton(onTap: onBack),
                  Flexible(child: _StatusChip(photo: photo)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(37, 28, 37, 34),
                child: SizedBox.expand(
                  child: LocalImage(
                    photo.path,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: colors.skeleton),
                    frameBuilder: (context, child, frame, wasSynchronous) =>
                        ColoredBox(color: colors.skeleton, child: child),
                  ),
                ),
              ),
            ),
            _ActionSheet(
              photo: photo,
              onAskAi: onAskAi,
              onChangePhoto: onChangePhoto,
              onSkipAi: onSkipAi,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FaunaLensTheme.of(context);
    return Semantics(
      button: true,
      label: 'Back to camera',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.backButton,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colors.backIcon,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.photo});

  final FaunaLensPhoto photo;

  @override
  Widget build(BuildContext context) {
    final colors = FaunaLensTheme.of(context);
    final isGallery = photo.source == FaunaLensPhotoSource.gallery;
    final isFound = photo.locationStatus == FaunaLensLocationStatus.found;
    final Widget icon;
    final String label;
    if (isGallery) {
      icon = FaunaLensPictureIcon(
        size: 17,
        color: colors.chipGalleryIcon,
        background: colors.chipGallery,
      );
      label = 'From your gallery';
    } else {
      icon = Icon(
        switch (photo.locationStatus) {
          FaunaLensLocationStatus.locating => Icons.my_location_rounded,
          FaunaLensLocationStatus.found => Icons.check_rounded,
          FaunaLensLocationStatus.missing => Icons.location_off_rounded,
        },
        color: isFound ? colors.chipCheck : colors.chipLocationText,
        size: 17,
      );
      label = switch (photo.locationStatus) {
        FaunaLensLocationStatus.locating => 'Getting location',
        FaunaLensLocationStatus.found => 'Location captured',
        FaunaLensLocationStatus.missing => 'No location',
      };
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isGallery ? colors.chipGallery : colors.chipLocation,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: isGallery
                    ? colors.chipGalleryText
                    : colors.chipLocationText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({
    required this.photo,
    required this.onAskAi,
    required this.onChangePhoto,
    required this.onSkipAi,
  });

  final FaunaLensPhoto photo;
  final VoidCallback onAskAi;
  final VoidCallback onChangePhoto;
  final VoidCallback onSkipAi;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isGallery = photo.source == FaunaLensPhotoSource.gallery;
    final hasNoLocation =
        photo.locationStatus == FaunaLensLocationStatus.missing;
    final colors = FaunaLensTheme.of(context);

    // Short and landscape screens scroll the sheet and keep part of the photo.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    return Container(
      constraints: BoxConstraints(
        minHeight: math.min(333 + bottomInset, maxHeight),
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: colors.isDark ? colors.card : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(22, 28, 22, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isGallery ? 'Use this photo?' : 'Happy with this photo?',
                    style: GoogleFonts.dmSans(
                      color: colors.isDark
                          ? Colors.white
                          : AppColors.profileTitleNavy,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isGallery
                        ? 'Ask AI to suggest what animal this might be, or pick a different photo.'
                        : 'Ask AI to suggest what animal this might be, or retake it for a clearer shot.',
                    style: GoogleFonts.dmSans(
                      color: colors.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: hasNoLocation ? 13 : 26),
            if (hasNoLocation) ...[
              const _NoLocationNotice(),
              const SizedBox(height: 9),
            ],
            _AskAiButton(onTap: onAskAi),
            const SizedBox(height: 19),
            Row(
              children: [
                Expanded(
                  child: _OutlinedAction(
                    label: isGallery ? 'Choose another' : 'Retake photo',
                    borderColor: colors.outlineBorder,
                    textColor: colors.outlineText,
                    onTap: onChangePhoto,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OutlinedAction(
                    label: 'Skip AI',
                    borderColor: colors.isDark
                        ? const Color(0xFF64748B)
                        : AppColors.faunaLensSkipBorder,
                    textColor: colors.isDark
                        ? const Color(0xFFCBD5E1)
                        : AppColors.faunaLensSkipText,
                    onTap: onSkipAi,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoLocationNotice extends StatelessWidget {
  const _NoLocationNotice();

  @override
  Widget build(BuildContext context) {
    final colors = FaunaLensTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 10, 12),
      decoration: BoxDecoration(
        color: colors.notice,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.noticeBorder),
      ),
      child: Row(
        children: [
          FaunaLensPinIcon(color: colors.noticeText),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No location was found in this photo. You will set where you saw the animal when you post.',
              style: GoogleFonts.dmSans(
                color: colors.noticeText,
                fontSize: 11.8,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AskAiButton extends StatelessWidget {
  const _AskAiButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.faunaLensBlue,
                AppColors.faunaLensAskGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            'Ask AI',
            style: GoogleFonts.dmSans(
              color: AppColors.faunaLensYellow,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: FaunaLensTheme.of(context).outlineFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
