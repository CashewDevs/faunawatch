import 'package:flutter/material.dart';

/// How urgent a small label (tag or chip) looks, from calm to urgent.
///
/// Features choose a tone for their own values (for example a severity level)
/// and [TagColors] turns it into colours for light or dark mode.
enum TagTone { neutral, low, moderate, high, critical, invasive }

/// The background and text colour of a coloured tag.
///
/// Every pair keeps the text readable on its background (a contrast of at
/// least 4.5:1) in both light and dark mode.
@immutable
class TagColors {
  const TagColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  /// The colours of [tone] for the current light or dark mode.
  static TagColors of(BuildContext context, TagTone tone) =>
      forTone(tone, Theme.of(context).brightness);

  static TagColors forTone(TagTone tone, Brightness brightness) =>
      brightness == Brightness.dark ? _dark[tone]! : _light[tone]!;

  static const Map<TagTone, TagColors> _light = {
    TagTone.neutral: TagColors(
      background: Color(0xFFEEF1F6),
      foreground: Color(0xFF5B6B82),
    ),
    TagTone.low: TagColors(
      background: Color(0xFFDDF5E3),
      foreground: Color(0xFF1E6B2A),
    ),
    TagTone.moderate: TagColors(
      background: Color(0xFFFFF1C2),
      foreground: Color(0xFF7A5000),
    ),
    TagTone.high: TagColors(
      background: Color(0xFFFFE4CC),
      foreground: Color(0xFF963A00),
    ),
    TagTone.critical: TagColors(
      background: Color(0xFFFDE2DE),
      foreground: Color(0xFFB3261E),
    ),
    TagTone.invasive: TagColors(
      background: Color(0xFFFCE3D8),
      foreground: Color(0xFF6E2A10),
    ),
  };

  static const Map<TagTone, TagColors> _dark = {
    TagTone.neutral: TagColors(
      background: Color(0xFF334155),
      foreground: Color(0xFFCBD5E1),
    ),
    TagTone.low: TagColors(
      background: Color(0xFF16301C),
      foreground: Color(0xFFC8EBCB),
    ),
    TagTone.moderate: TagColors(
      background: Color(0xFF3D3410),
      foreground: Color(0xFFFFE08A),
    ),
    TagTone.high: TagColors(
      background: Color(0xFF3D2410),
      foreground: Color(0xFFFFC08A),
    ),
    TagTone.critical: TagColors(
      background: Color(0xFF3B1519),
      foreground: Color(0xFFFF8A80),
    ),
    TagTone.invasive: TagColors(
      background: Color(0xFF3B2317),
      foreground: Color(0xFFFFB59A),
    ),
  };
}
