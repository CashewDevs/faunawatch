import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Reusable pill-shaped text input field styled with brand icons and DM Sans typography.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.label,
    required this.prefixIconPath,
    required this.onChanged,
    super.key,
    this.initialValue,
    this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
  });

  final String label;
  final String prefixIconPath;
  final ValueChanged<String> onChanged;
  final String? initialValue;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: AppColors.loginDarkText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.loginFieldBackground,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.loginFieldBorder, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Image.asset(
                prefixIconPath,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  style: GoogleFonts.dmSans(
                    color: AppColors.loginDarkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              ?suffixIcon,
            ],
          ),
        ),
      ],
    );
  }
}
