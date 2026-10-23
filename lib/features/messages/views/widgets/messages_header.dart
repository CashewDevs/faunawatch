import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Top header for the Messages screen featuring a blue gradient and the
/// "Messages" title in DM Sans extrabold with a yellow accent underline.
class MessagesHeader extends StatelessWidget {
  const MessagesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0.0, 1.0],
          colors: [
            AppColors.messagesHeaderGradientStart,
            AppColors.messagesHeaderGradientEnd,
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
                        color: AppColors.messagesHeaderBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: AppColors.messagesHeaderUnderline,
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
