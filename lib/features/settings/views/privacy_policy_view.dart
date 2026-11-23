import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/terms/models/terms_section.dart';

/// Informational Privacy Policy screen explaining how FaunaWatch handles user
/// data, photos, locations, AI keys, and private chats.
class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPaletteColors.of(context);

    final headerBg = isDark ? AppColors.darkSurface : Colors.white;
    final titleColor = isDark ? scheme.primary : palette.navLabelBlue;
    final backColor = isDark ? scheme.primary : palette.shellHeaderBlue;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: headerBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.chevron_left_rounded, color: backColor, size: 30),
          ),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.dmSans(
            color: titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.25, 1.0],
            colors: isDark
                ? [
                    palette.darkProfileGradientStart,
                    palette.darkProfileGradientEnd,
                  ]
                : [
                    palette.profileBackgroundGradientStart,
                    palette.profileBackgroundGradientEnd,
                  ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _PolicyCard(
                isDark: isDark,
                title: 'Photos and wildlife reports',
                body:
                    'Photos and details you submit in approved wildlife reports '
                    'are visible to other FaunaWatch community members. If you '
                    'turn on "Private posts" in Settings, other people can no '
                    'longer browse your posts on your profile, but your '
                    'approved reports still appear in the Feed and on the '
                    'map. Before sending photos to an AI provider or private '
                    'chat, FaunaWatch strips EXIF and GPS metadata.',
              ),
              const SizedBox(height: 14),
              _PolicyCard(
                isDark: isDark,
                title: 'Location privacy',
                body:
                    'Location data is used to map wildlife sightings and warn '
                    'nearby users. Other users always see a nearby area '
                    '(about 100 m) instead of your exact spot. Only you and '
                    'FaunaWatch admins can see the exact location.',
              ),
              const SizedBox(height: 14),
              _PolicyCard(
                isDark: isDark,
                title: 'Your AI API keys',
                body:
                    'If you connect your own Gemini, Groq, or OpenRouter API '
                    'key, it is stored locally using encrypted device storage '
                    '(Android Keystore or iOS Keychain). Your API keys are '
                    'never sent to FaunaWatch servers.',
              ),
              const SizedBox(height: 14),
              _PolicyCard(
                isDark: isDark,
                title: 'Private chats and account controls',
                body:
                    'One-to-one messages and private chat photos can only be '
                    'read by the two participants in that conversation. You '
                    'can update your profile, change your password, adjust '
                    'privacy and notification preferences, or sign out at any '
                    'time.',
              ),
              const SizedBox(height: 16),
              Text(
                'Policy version $termsVersion',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.isDark,
    required this.title,
    required this.body,
  });

  final bool isDark;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? AppColors.darkTextBody : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
