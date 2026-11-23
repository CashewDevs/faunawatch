import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Shows or hides a password field's text.
class PasswordVisibilityButton extends StatelessWidget {
  const PasswordVisibilityButton({
    required this.isVisible,
    required this.onPressed,
    super.key,
  });

  final bool isVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isVisible ? 'Hide password' : 'Show password',
      onPressed: onPressed,
      icon: Image.asset(
        isVisible ? AppAssets.seePasswordIcon : AppAssets.hidePasswordIcon,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// One password rule, ticked when met (same look as Change Password).
class PasswordRequirement extends StatelessWidget {
  const PasswordRequirement({
    required this.label,
    required this.met,
    super.key,
  });

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      label: '$label: ${met ? 'met' : 'not met'}',
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: met ? AppColors.primarySeed : Colors.transparent,
              border: met
                  ? null
                  : Border.all(color: const Color(0xFF94A3B8), width: 1.6),
            ),
            alignment: Alignment.center,
            child: met
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: met ? const Color(0xFF334155) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
