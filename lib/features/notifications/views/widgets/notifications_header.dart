import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top header for the Notifications screen featuring a horizontal blue gradient
/// and the "Notifications" title in DM Sans extrabold with a yellow accent underline.
class NotificationsHeader extends StatelessWidget {
  const NotificationsHeader({super.key, this.onClearAll});

  /// Called when "Clear all" is chosen. When null (nothing to clear) the menu
  /// is hidden.
  final VoidCallback? onClearAll;

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
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
              ),
              if (onClearAll != null)
                PopupMenuButton<String>(
                  tooltip: 'Notification options',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark
                        ? AppPaletteColors.of(context).darkAccentBlue
                        : AppPaletteColors.of(context).messagesHeaderBlue,
                  ),
                  onSelected: (_) => onClearAll!(),
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'clear_all',
                      child: Text('Clear all'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
