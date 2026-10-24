import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Pill-shaped white input field with navy stroke and bottom character count.
class ProfileInputField extends StatelessWidget {
  const ProfileInputField({
    super.key,
    required this.maxLength,
    required this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.hintText,
  });

  final int maxLength;
  final ValueChanged<String> onChanged;
  final TextInputAction textInputAction;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.profileFieldBorder, width: 2),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            maxLength: maxLength,
            textInputAction: textInputAction,
            cursorColor: AppColors.profileTitleNavy,
            style: GoogleFonts.dmSans(
              color: AppColors.profileTitleNavy,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
              hintText: hintText,
              hintStyle: GoogleFonts.dmSans(
                color: AppColors.profileCounterText.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
