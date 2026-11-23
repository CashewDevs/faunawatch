import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// The look shared by the Forgot password screens, matching the Login
/// screen: blue-to-white background, yellow title, white rounded sheet.
class PasswordResetFrame extends StatelessWidget {
  const PasswordResetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Shows a back arrow when set.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.loginGradientTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.loginGradientTop, AppColors.loginGradientBottom],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 56,
                child: onBack == null
                    ? null
                    : IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 8, 36, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: GoogleFonts.dmSans(
                          color: AppColors.loginTitleYellow,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.05 * 34,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A red (error) or blue (info) message inside the sheet.
class PasswordResetMessage extends StatelessWidget {
  const PasswordResetMessage({
    required this.message,
    super.key,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? const Color(0xFFF87171) : const Color(0xFF93C5FD),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: isError
                ? AppColors.notifsBadgeRed
                : AppColors.loginForgotPasswordBlue,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                color: isError
                    ? const Color(0xFF991B1B)
                    : AppColors.loginDarkText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Body text inside the sheet.
class PasswordResetText extends StatelessWidget {
  const PasswordResetText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        color: AppColors.loginDarkText,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
    );
  }
}

/// A plain text button in the Login screen's link blue.
class PasswordResetLinkButton extends StatelessWidget {
  const PasswordResetLinkButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: AppColors.loginForgotPasswordBlue,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
