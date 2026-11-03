import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Full-width rounded button used on the consent and AI key setup screens.
///
/// The primary style is a yellow gradient; the secondary style is a white
/// outline. A disabled button fades out and ignores taps.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final radius = BorderRadius.circular(26);

    return AnimatedOpacity(
      opacity: onPressed == null ? 0.5 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: isPrimary ? null : Colors.white,
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [
                    AppColors.profileButtonGradientStart,
                    AppColors.profileButtonGradientEnd,
                  ],
                )
              : null,
          border: Border.all(
            color: isPrimary
                ? AppColors.consentButtonBorder
                : AppColors.consentMutedText.withValues(alpha: 0.5),
          ),
          boxShadow: isPrimary && onPressed != null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    offset: const Offset(0, 3),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Center(
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.consentTitleNavy,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.dmSans(
                        color: AppColors.consentTitleNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
