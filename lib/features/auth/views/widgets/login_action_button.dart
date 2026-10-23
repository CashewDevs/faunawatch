import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// The dual-state Log In button reflecting disabled (unpressed) and enabled states.
class LoginActionButton extends StatelessWidget {
  const LoginActionButton({
    required this.isEnabled,
    required this.onPressed,
    super.key,
    this.label = 'Log In',
    this.isLoading = false,
  });

  final String label;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const double borderRadius = 36;
    const double height = 58;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isEnabled ? null : AppColors.loginButtonUnpressedBackground,
        gradient: isEnabled
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.loginButtonGradientStart,
                  AppColors.loginButtonGradientEnd,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isEnabled
              ? AppColors.loginButtonStroke
              : AppColors.loginButtonUnpressedBorder,
          width: isEnabled ? 3.0 : 2.0,
        ),
        boxShadow: isEnabled
            ? const [
                BoxShadow(
                  color: Color(0x38000000),
                  offset: Offset(0, 5),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: isEnabled && !isLoading ? onPressed : null,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.loginButtonStroke,
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isEnabled
                          ? AppColors.loginButtonStroke
                          : AppColors.loginButtonUnpressedText,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
