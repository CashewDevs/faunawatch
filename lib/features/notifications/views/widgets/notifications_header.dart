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
    final titleColor = isDark
        ? AppPaletteColors.of(context).darkAccentBlue
        : AppPaletteColors.of(context).messagesHeaderBlue;
    // The list opens as a page from the Feed bell, so it offers a way back.
    final canGoBack = Navigator.of(context).canPop();
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
          padding: EdgeInsets.fromLTRB(canGoBack ? 4 : 20, 20, 20, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (canGoBack)
                IconButton(
                  tooltip: 'Back',
                  icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
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
                          color: titleColor,
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
                  icon: Icon(Icons.more_vert_rounded, color: titleColor),
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
