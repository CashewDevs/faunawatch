import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top header for the Notifications screen featuring a horizontally flipped
/// blue gradient and the right-aligned "Notifications" title in DM Sans
/// extrabold with a yellow accent underline.
class NotificationsHeader extends StatelessWidget {
  const NotificationsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPaletteColors.of(context);
    final titleColor = isDark
        ? palette.darkAccentBlue
        : palette.messagesHeaderBlue;
    // The list opens as a page from the Feed bell, so it offers a way back.
    final canGoBack = Navigator.of(context).canPop();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          stops: const [0.0, 1.0],
          colors: isDark
              ? [palette.darkHeaderGradientStart, palette.darkHeaderGradientEnd]
              : [
                  palette.messagesHeaderGradientStart,
                  palette.messagesHeaderGradientEnd,
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(canGoBack ? 4 : 20, 20, 20, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (canGoBack)
                IconButton(
                  tooltip: 'Back',
                  icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Notifications',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: GoogleFonts.dmSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: palette.messagesHeaderUnderline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
