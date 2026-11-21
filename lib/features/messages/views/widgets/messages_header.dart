import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top header for the Messages screen featuring a blue gradient and the
/// "Messages" title in DM Sans extrabold with a yellow accent underline.
class MessagesHeader extends StatelessWidget {
  const MessagesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 1.0],
          colors: isDark
              ? [
                  AppPaletteColors.of(context).darkHeaderGradientStart,
                  AppPaletteColors.of(context).darkHeaderGradientEnd,
                ]
              : [
                  AppPaletteColors.of(context).messagesHeaderGradientStart,
                  AppPaletteColors.of(context).messagesHeaderGradientEnd,
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Messages',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.dmSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppPaletteColors.of(context).darkAccentBlue
                            : AppPaletteColors.of(context).messagesHeaderBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: AppPaletteColors.of(
                          context,
                        ).messagesHeaderUnderline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
