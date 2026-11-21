import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The colours of the FaunaLens screens after the camera ("Use this photo?",
/// "Choose animals" and "AI Result"), following the app's light or dark mode
/// and palette. In light mode with the Apollo palette they are the original
/// FaunaLens design.
///
/// The live camera stays dark, and the animal box colours never change.
@immutable
class FaunaLensTheme {
  const FaunaLensTheme._({
    required this.isDark,
    required this.page,
    required this.header,
    required this.accent,
    required this.title,
    required this.body,
    required this.muted,
    required this.card,
    required this.cardBorder,
    required this.info,
    required this.infoBorder,
    required this.invasive,
    required this.invasiveText,
    required this.skeleton,
    required this.rank,
    required this.badge,
    required this.badgeText,
    required this.reviewTop,
    required this.backButton,
    required this.backIcon,
    required this.outlineFill,
    required this.outlineBorder,
    required this.outlineText,
  });

  factory FaunaLensTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPaletteColors.of(context);
    final scheme = theme.colorScheme;
    if (theme.brightness == Brightness.dark) {
      return FaunaLensTheme._(
        isDark: true,
        page: theme.scaffoldBackgroundColor,
        header: AppColors.darkSurface,
        accent: palette.darkAccentBlue,
        title: Colors.white,
        body: const Color(0xFFCBD5E1),
        muted: const Color(0xFF94A3B8),
        card: AppColors.darkSurface,
        cardBorder: const Color(0xFF334155),
        info: const Color(0xFF172A46),
        infoBorder: const Color(0xFF2B4572),
        invasive: const Color(0xFF3B2317),
        invasiveText: const Color(0xFFFFB59A),
        skeleton: const Color(0xFF334155),
        rank: const Color(0xFF1E3A5F),
        badge: const Color(0xFF3D3410),
        badgeText: AppColors.faunaLensYellow,
        reviewTop: theme.scaffoldBackgroundColor,
        backButton: AppColors.darkSurface,
        backIcon: Colors.white,
        outlineFill: AppColors.darkSurface,
        outlineBorder: const Color(0xFF475569),
        outlineText: Colors.white,
      );
    }
    return FaunaLensTheme._(
      isDark: false,
      page: Colors.white,
      header: palette.resolve(
        AppColors.aiResultHeader,
        scheme.primaryContainer,
      ),
      accent: palette.resolve(AppColors.faunaLensBlue, scheme.primary),
      title: AppColors.consentTitleNavy,
      body: AppColors.consentBodyText,
      muted: AppColors.consentMutedText,
      card: Colors.white,
      cardBorder: AppColors.aiResultCardBorder,
      info: palette.resolve(
        AppColors.aiResultInfoBackground,
        scheme.surfaceContainerLow,
      ),
      infoBorder: palette.resolve(
        AppColors.aiResultInfoBorder,
        scheme.outlineVariant,
      ),
      invasive: AppColors.aiResultInvasiveBackground,
      invasiveText: AppColors.aiResultInvasiveText,
      skeleton: AppColors.aiResultSkeleton,
      rank: palette.resolve(
        AppColors.aiResultRankBackground,
        scheme.primaryContainer,
      ),
      badge: AppColors.consentBadgeYellowBackground,
      badgeText: AppColors.consentTitleNavy,
      reviewTop: palette.resolve(
        AppColors.profileGradientTop,
        scheme.primaryContainer,
      ),
      backButton: AppColors.faunaLensBackButton,
      backIcon: AppColors.faunaLensInk,
      outlineFill: Colors.white,
      outlineBorder: AppColors.faunaLensInk,
      outlineText: AppColors.faunaLensInk,
    );
  }

  final bool isDark;

  /// Behind everything.
  final Color page;

  /// The top bar of "Choose animals" and "AI Result".
  final Color header;

  /// Headings, labels and links.
  final Color accent;
  final Color title;
  final Color body;
  final Color muted;
  final Color card;
  final Color cardBorder;

  /// The tinted cards for condition and severity.
  final Color info;
  final Color infoBorder;
  final Color invasive;
  final Color invasiveText;

  /// Placeholders while loading.
  final Color skeleton;

  /// The circles behind the lower-ranked guesses.
  final Color rank;

  /// The "Preliminary AI assessment" badge.
  final Color badge;
  final Color badgeText;

  /// Behind the photo on "Use this photo?".
  final Color reviewTop;
  final Color backButton;
  final Color backIcon;

  /// Secondary outlined buttons.
  final Color outlineFill;
  final Color outlineBorder;
  final Color outlineText;

  /// Status bar icons that stay readable on [page].
  SystemUiOverlayStyle get statusBar =>
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}
