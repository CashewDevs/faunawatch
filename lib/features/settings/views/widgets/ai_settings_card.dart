import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';

// The building blocks of the AI Integration look, shared by Settings › AI
// Integration and the first-time "Power up FaunaLens" screen.

/// A small grey capital-letter title above a card, e.g. "PROVIDER".
class AiSettingsSectionHeader extends StatelessWidget {
  const AiSettingsSectionHeader(this.title, {super.key, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// A rounded card holding [AiSettingsRow]s, with lines between them.
class AiSettingsCard extends StatelessWidget {
  const AiSettingsCard({
    super.key,
    required this.isDark,
    required this.children,
  });

  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divider, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// One tappable row: icon, title, subtitle, optional content below and an
/// optional trailing widget.
class AiSettingsRow extends StatelessWidget {
  const AiSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    this.iconColor,
    this.subtitleColor,
    this.below,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? subtitleColor;
  final Widget? below;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? AppPaletteColors.of(context).shellHeaderBlue,
              size: 26,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: subtitleColor ?? muted,
                      fontWeight: subtitleColor == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                  if (below != null) ...[const SizedBox(height: 8), below!],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              IconTheme(
                data: IconThemeData(color: muted),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The rounded label showing a chosen provider.
class AiProviderPill extends StatelessWidget {
  const AiProviderPill({super.key, required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppPaletteColors.of(
                context,
              ).shellHeaderBlue.withValues(alpha: 0.2)
            : AppColors.consentBadgeBlueBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.consentBadgeBlueText,
        ),
      ),
    );
  }
}
