import 'package:flutter/material.dart';

/// Centralized color constants for FaunaWatch.
abstract final class AppColors {
  // Brand & Theme
  static const Color primarySeed = Color(0xFF1B5E20);
  static const Color welcomeBackgroundTone = Color(0xFF1B63D8);

  // Welcome Screen Neo-brutalist / Pop Palette
  static const Color welcomeLoginButton = Color(0xFFA5D8F9);
  static const Color welcomeSignUpButton = Color(0xFFFED965);
  static const Color buttonBorder = Color(0xFF000000);
  static const Color buttonShadow = Color(0xFF000000);

  // Login Screen Palette
  static const Color loginHeaderBlue = Color(0xFF2A6EE2);
  static const Color loginGradientTop = Color(0xFF1A5DC9);
  static const Color loginGradientBottom = Color(0xFFFFFFFF);
  static const Color loginTitleYellow = Color(0xFFFFD400);
  static const Color loginSubtitleBlue = Color(0xFF93C5FD);
  static const Color loginDarkText = Color(0xFF0F1A3C);
  static const Color loginFieldBackground = Color(0xFFF7F5F0);
  static const Color loginFieldBorder = Color(0xFFC7BBA5);
  static const Color loginForgotPasswordBlue = Color(0xFF2D6CE3);

  // Login Button States
  static const Color loginButtonUnpressedBackground = Color(0xFFFFFBE8);
  static const Color loginButtonUnpressedBorder = Color(0xFF8CA5B5);
  static const Color loginButtonUnpressedText = Color(0xFF8CA5B5);

  static const Color loginButtonGradientStart = Color(0xFFFFF4C3);
  static const Color loginButtonGradientEnd = Color(0xFFFFD807);
  static const Color loginButtonStroke = Color(0xFF1A5DC9);
  static const Color loginButtonActiveBorder = Color(0xFF1967D2);
  static const Color loginButtonActiveText = Color(0xFF1B4F8A);

  // Divider & Social Login
  static const Color loginDividerLine = Color(0xFF8CAAC6);
  static const Color loginDividerText = Color(0xFF3B6B9B);
  static const Color loginGoogleButtonBackground = Color(0xFFFFFDEE);
  static const Color loginGoogleButtonBorder = Color(0xFF5E8CAE);
  static const Color loginSignUpYellowDark = Color(0xFFC78400);

  // Profile Customization Screen Palette
  static const Color profileGradientTop = Color(0xFFAECDFF);
  static const Color profileGradientBottom = Color(0xFFFFF4C3);
  static const Color profileTitleNavy = Color(0xFF05004E);
  static const Color profileFieldBorder = Color(0xFF05004E);
  static const Color profileCounterText = Color(0xFF6E8CAE);
  static const Color profileButtonGradientStart = Color(0xFFFFD807);
  static const Color profileButtonGradientEnd = Color(0xFFFCB52C);
  static const Color profileButtonDisabledBackground = Color(0xFFECECEC);
  static const Color profileButtonDisabledText = Color(0xFF8E8E93);
  static const Color profileButtonDisabledBorder = Color(0xFFB0B0B0);
  static const Color profileButtonBorder = Color(0xFF000000);
  static const Color profileSelectedOrange = Color(0xFFFFA100);

  // Profile Banner Colors
  static const List<Color> bannerColors = [
    Color(0xFFFBB9C5),
    Color(0xFFFDD0B1),
    Color(0xFFF9EFC7),
    Color(0xFFC3EFBF),
    Color(0xFFB8DFE6),
    Color(0xFFC5BBDE),
  ];

  // Intro Screen Palette
  static const Color introSlideUpText = Color(0xFF5A9EED);

  // Onboarding Walkthrough Palette
  static const Color onboardingBackground = Color(0xFFAECDFF);
  static const Color onboardingIndicatorActive = Color(0xFFFECE01);
  static const Color onboardingIndicatorInactive = Color(0xFFD6E2F0);
  static const Color onboardingButtonGradientStart = Color(0xFFF9DC5F);
  static const Color onboardingButtonGradientEnd = Color(0xFFB2EFFF);
  static const Color onboardingButtonBorder = Color(0xFF005A97);
  static const Color onboardingHeaderBlack = Color(0xFF000000);
  static const Color onboardingSubheadingDark = Color(0xFF0F1A3C);

  // Shell Dashboard & Navigation Bar
  static const Color shellHeaderBlue = Color(0xFF1A5DC9);
  static const Color navLabelBlue = Color(0xFF005A97);
  static const Color navActiveBorder = Color(0xFFFFF2BD);
  static const Color navActiveBackground = Color(0xFFFFFEE6);

  // Search Screen Palette
  static const Color searchHeaderBlue = Color(0xFF1A5DC9);
  static const Color searchHeaderBackground = Color(0xFFDCF2FF);
  static const Color searchFieldStroke = Color(0xFFB4A97C);

  // Messages Screen Palette
  static const Color messagesHeaderGradientStart = Color(0xFFDCF2FF);
  static const Color messagesHeaderGradientEnd = Color(0xFFA4DDFF);
  static const Color messagesHeaderBlue = Color(0xFF1A5DC9);
  static const Color messagesHeaderUnderline = Color(0xFFFECE01);
  static const Color messagesSearchBorder = Color(0xFF1A5DC9);
  static const Color messagesUnreadBar = Color(0xFFFECE01);
  static const Color messagesUnreadBackground = Color(0xFFFFFBE9);
  static const Color messagesPfpPlaceholder = Color(0xFFD9D9D9);
  static const Color messagesFilterSelected = Color(0xFFFFF4C3);
  static const Color messagesFilterUnselected = Color(0xFFFFFBE9);

  // Chat Conversation Palette
  static const Color chatHeaderBackground = Color(0xFFFFFBE9);
  static const Color chatUserBubbleGradientStart = Color(0xFFA4DDFF);
  static const Color chatUserBubbleGradientEnd = Color(0xFFDCF2FF);
  static const Color chatOtherBubbleGradientStart = Color(0xFFD5D5D5);
  static const Color chatOtherBubbleGradientEnd = Color(0xFFE8E8E8);
  static const Color chatInputHintColor = Color(0xFFB4A97C);

  // Gallery Screen Palette
  static const Color galleryBackgroundGradientStart = Color(0xFFDCF2FF);
  static const Color galleryBackgroundGradientEnd = Color(0xFFA4DDFF);
  static const Color galleryTitleBlue = Color(0xFF1A5DC9);
  static const Color galleryTitleUnderline = Color(0xFFFECE01);
  static const Color galleryCardDetailsYellow = Color(0xFFFFF7D6);
  static const Color galleryFilterButtonBackground = Color(0xFFFFF7D6);
  static const Color galleryFilterButtonBorder = Color(0xFF1A5DC9);

  // Feed Palette
  static const Color feedLikeRed = Color(0xFFFE2C55);
  static const Color feedCreatorTeal = Color(0xFF00838F);
  static const Color feedCreatorTealDark = Color(0xFF4DD0E1);

  // Notifications Screen Palette
  static const Color notifsBadgeRed = Color(0xFFE53935);

  // Profile Screen Palette
  static const Color profileBackgroundGradientStart = Color(0xFFFAF9F6);
  static const Color profileBackgroundGradientEnd = Color(0xFFB2EFFF);
  static const Color profileDefaultBanner = Color(0xFFBCE7B4);
  static const Color profileDivider = Color(0xFF1E1E1E);
  static const Color signOutButtonRed = Color(0xFFB31818);
  static const Color signOutTextYellow = Color(0xFFFECE01);

  // Dark Theme Tokens
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkProfileGradientStart = Color(0xFF0F172A);
  static const Color darkProfileGradientEnd = Color(0xFF082F49);
}
