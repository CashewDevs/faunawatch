import 'package:flutter/material.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';

/// Colours of the AI Integration look (cards, rows, the key pop-up and the
/// AI Keys Agreement), for the current light or dark theme.
class AiSettingsStyle {
  const AiSettingsStyle._({
    required this.isDark,
    required this.accent,
    required this.sheet,
    required this.card,
    required this.border,
    required this.title,
    required this.muted,
  });

  factory AiSettingsStyle.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AiSettingsStyle._(
      isDark: isDark,
      accent: AppPaletteColors.of(context).shellHeaderBlue,
      sheet: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      card: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      title: isDark ? Colors.white : const Color(0xFF1E293B),
      muted: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );
  }

  final bool isDark;

  /// The app's header blue: icons, links and the main button.
  final Color accent;

  /// Background of a bottom sheet, behind its cards.
  final Color sheet;
  final Color card;

  /// Card borders and the lines between rows.
  final Color border;
  final Color title;
  final Color muted;

  /// A soft accent fill, e.g. behind an icon.
  Color get accentTint => accent.withValues(alpha: isDark ? 0.22 : 0.1);
}
