import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// The final CTA button in the onboarding walkthrough ("Begin the Watch").
///
/// Features a gradient from #F9DC5F to #B2EFFF, a 3 pt outer stroke in
/// [AppColors.onboardingButtonBorder], DM Sans bold typography, and a drop shadow.
class BeginWatchButton extends StatefulWidget {
  const BeginWatchButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<BeginWatchButton> createState() => _BeginWatchButtonState();
}

class _BeginWatchButtonState extends State<BeginWatchButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Begin the Watch',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.onboardingButtonGradientStart,
                  AppColors.onboardingButtonGradientEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(29),
              border: Border.all(
                color: AppColors.onboardingButtonBorder,
                width: 3.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'Begin the Watch',
              style: GoogleFonts.dmSans(
                color: AppColors.onboardingSubheadingDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
