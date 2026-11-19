import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Retains Apollo's original UI colors alongside the generated palettes.
/// Theme interpolation blends both the palette and the original design.
@immutable
class AppPaletteColors extends ThemeExtension<AppPaletteColors> {
  const AppPaletteColors({required this.scheme, this.apolloWeight = 0});
  final ColorScheme scheme;
  final double apolloWeight;

  static AppPaletteColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPaletteColors>() ??
        AppPaletteColors(scheme: theme.colorScheme, apolloWeight: 1);
  }

  Color resolve(Color original, Color themed) =>
      Color.lerp(themed, original, apolloWeight)!;
  Color get shellHeaderBlue =>
      resolve(AppColors.shellHeaderBlue, scheme.primary);
  Color get navLabelBlue => resolve(AppColors.navLabelBlue, scheme.primary);
  Color get navActiveBorder =>
      resolve(AppColors.navActiveBorder, scheme.primary);
  Color get navActiveBackground =>
      resolve(AppColors.navActiveBackground, scheme.primaryContainer);
  Color get galleryTitleBlue =>
      resolve(AppColors.galleryTitleBlue, scheme.primary);
  Color get galleryFilterButtonBorder =>
      resolve(AppColors.galleryFilterButtonBorder, scheme.primary);
  Color get galleryFilterButtonBackground => resolve(
    AppColors.galleryFilterButtonBackground,
    scheme.surfaceContainerHigh,
  );
  Color get galleryCardDetailsYellow =>
      resolve(AppColors.galleryCardDetailsYellow, scheme.secondaryContainer);
  Color get messagesHeaderBlue =>
      resolve(AppColors.messagesHeaderBlue, scheme.primary);
  Color get darkAccentBlue => resolve(AppColors.darkAccentBlue, scheme.primary);
  Color get messagesSearchBorder =>
      resolve(AppColors.messagesSearchBorder, scheme.primary);
  Color get messagesHeaderUnderline =>
      resolve(AppColors.messagesHeaderUnderline, scheme.primary);
  Color get messagesHeaderGradientStart =>
      resolve(AppColors.messagesHeaderGradientStart, scheme.surface);
  Color get messagesHeaderGradientEnd =>
      resolve(AppColors.messagesHeaderGradientEnd, scheme.primaryContainer);
  Color get darkHeaderGradientStart =>
      resolve(AppColors.darkHeaderGradientStart, scheme.surface);
  Color get darkHeaderGradientEnd =>
      resolve(AppColors.darkHeaderGradientEnd, scheme.primaryContainer);
  Color get messagesUnreadBar =>
      resolve(AppColors.messagesUnreadBar, scheme.primary);
  Color get messagesUnreadBackground =>
      resolve(AppColors.messagesUnreadBackground, scheme.primaryContainer);
  Color get messagesFilterSelected =>
      resolve(AppColors.messagesFilterSelected, scheme.primaryContainer);
  Color get messagesFilterUnselected =>
      resolve(AppColors.messagesFilterUnselected, scheme.surfaceContainerLow);
  Color get darkUnreadBackground =>
      resolve(AppColors.darkUnreadBackground, scheme.primaryContainer);
  Color get darkFilterSelected =>
      resolve(AppColors.darkFilterSelected, scheme.primaryContainer);
  Color get chatUserBubbleGradientStart =>
      resolve(AppColors.chatUserBubbleGradientStart, scheme.primaryContainer);
  Color get chatUserBubbleGradientEnd =>
      resolve(AppColors.chatUserBubbleGradientEnd, scheme.secondaryContainer);
  Color get darkChatUserBubbleGradientStart => resolve(
    AppColors.darkChatUserBubbleGradientStart,
    scheme.primaryContainer,
  );
  Color get darkChatUserBubbleGradientEnd => resolve(
    AppColors.darkChatUserBubbleGradientEnd,
    scheme.secondaryContainer,
  );
  Color get profileBackgroundGradientStart =>
      resolve(AppColors.profileBackgroundGradientStart, scheme.surface);
  Color get profileBackgroundGradientEnd =>
      resolve(AppColors.profileBackgroundGradientEnd, scheme.primaryContainer);
  Color get darkProfileGradientStart =>
      resolve(AppColors.darkProfileGradientStart, scheme.surface);
  Color get darkProfileGradientEnd =>
      resolve(AppColors.darkProfileGradientEnd, scheme.primaryContainer);
  Color get profileButtonGradientStart =>
      resolve(AppColors.profileButtonGradientStart, scheme.primary);
  Color get profileButtonGradientEnd =>
      resolve(AppColors.profileButtonGradientEnd, scheme.primary);
  Color get searchHeaderBlue =>
      resolve(AppColors.searchHeaderBlue, scheme.primary);
  Color get searchHeaderBackground =>
      resolve(AppColors.searchHeaderBackground, scheme.primaryContainer);
  Color get searchFieldStroke =>
      resolve(AppColors.searchFieldStroke, scheme.outline);
  Color get onPrimary => resolve(Colors.white, scheme.onPrimary);

  @override
  AppPaletteColors copyWith({ColorScheme? scheme, double? apolloWeight}) =>
      AppPaletteColors(
        scheme: scheme ?? this.scheme,
        apolloWeight: apolloWeight ?? this.apolloWeight,
      );

  @override
  AppPaletteColors lerp(covariant AppPaletteColors? other, double t) {
    if (other == null) return this;
    return AppPaletteColors(
      scheme: ColorScheme.lerp(scheme, other.scheme, t),
      apolloWeight: lerpDouble(apolloWeight, other.apolloWeight, t)!,
    );
  }
}
