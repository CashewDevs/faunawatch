import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/profile/viewmodels/change_password_viewmodel.dart';

/// Screen allowing the signed-in user to update their sign-in password while
/// staying signed in on the current device.
class ChangePasswordView extends ConsumerStatefulWidget {
  const ChangePasswordView({super.key});

  @override
  ConsumerState<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends ConsumerState<ChangePasswordView> {
  late final TextEditingController _currentController;
  late final TextEditingController _newController;
  late final TextEditingController _confirmController;

  @override
  void initState() {
    super.initState();
    _currentController = TextEditingController();
    _newController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    FocusScope.of(context).unfocus();
    final updated = await ref
        .read(changePasswordViewModelProvider.notifier)
        .submit();
    if (!mounted || !updated) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated successfully.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _handleForgotPassword() async {
    FocusScope.of(context).unfocus();
    await ref.read(changePasswordViewModelProvider.notifier).sendResetEmail();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordViewModelProvider);
    final notifier = ref.read(changePasswordViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPaletteColors.of(context);

    final pageBg = isDark ? AppColors.darkBackground : const Color(0xFFF6F8FB);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final cardBorder = isDark ? AppColors.darkBorder : const Color(0xFFE5EAF0);
    final headerBg = isDark ? AppColors.darkSurface : Colors.white;
    final titleColor = isDark ? scheme.primary : palette.navLabelBlue;
    final backColor = isDark ? scheme.primary : palette.shellHeaderBlue;
    final labelColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF5B6B7F);
    final linkColor = isDark
        ? AppColors.darkAccentBlue
        : AppColors.loginForgotPasswordBlue;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: headerBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.chevron_left_rounded, color: backColor, size: 30),
          ),
        ),
        title: Text(
          'Change Password',
          style: GoogleFonts.dmSans(
            color: titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pick a new password you do not use anywhere else.\n'
                  'You will stay signed in on this device.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 16),
                // Password Fields Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.04,
                        ),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Current password', color: labelColor),
                      const SizedBox(height: 8),
                      _PasswordInputField(
                        fieldKey: const ValueKey('current_password_field'),
                        controller: _currentController,
                        obscureText: state.obscureCurrent,
                        hintText: 'Enter current password',
                        toggleTooltip: state.obscureCurrent
                            ? 'Show current password'
                            : 'Hide current password',
                        textInputAction: TextInputAction.next,
                        isDark: isDark,
                        focusedBorderColor: linkColor,
                        onChanged: notifier.setCurrentPassword,
                        onToggleVisibility: notifier.toggleObscureCurrent,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: state.isSendingReset
                            ? null
                            : _handleForgotPassword,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            state.isSendingReset
                                ? 'Sending reset link...'
                                : 'Forgot your password?',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: linkColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel('New password', color: labelColor),
                      const SizedBox(height: 8),
                      _PasswordInputField(
                        fieldKey: const ValueKey('new_password_field'),
                        controller: _newController,
                        obscureText: state.obscureNew,
                        hintText: 'Enter new password',
                        toggleTooltip: state.obscureNew
                            ? 'Show new password'
                            : 'Hide new password',
                        textInputAction: TextInputAction.next,
                        isDark: isDark,
                        focusedBorderColor: linkColor,
                        onChanged: notifier.setNewPassword,
                        onToggleVisibility: notifier.toggleObscureNew,
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel('Confirm new password', color: labelColor),
                      const SizedBox(height: 8),
                      _PasswordInputField(
                        fieldKey: const ValueKey('confirm_password_field'),
                        controller: _confirmController,
                        obscureText: state.obscureConfirm,
                        hintText: 'Type it again',
                        toggleTooltip: state.obscureConfirm
                            ? 'Show confirm password'
                            : 'Hide confirm password',
                        textInputAction: TextInputAction.done,
                        isDark: isDark,
                        focusedBorderColor: linkColor,
                        onChanged: notifier.setConfirmPassword,
                        onToggleVisibility: notifier.toggleObscureConfirm,
                        onSubmitted: (_) => _handleUpdatePassword(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Password Requirements Checklist Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : const Color(0xFFFDFEFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.03,
                        ),
                        offset: const Offset(0, 3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your password needs',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RequirementRow(
                        label: 'At least 8 characters',
                        met: state.hasMinLength,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _RequirementRow(
                        label: 'A letter and a number',
                        met: state.hasLetterAndNumber,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _RequirementRow(
                        label: 'Matches the confirmation',
                        met: state.matchesConfirmation,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _FeedbackBanner(
                    message: state.errorMessage!,
                    isError: true,
                    isDark: isDark,
                  ),
                ],
                if (state.infoMessage != null) ...[
                  const SizedBox(height: 14),
                  _FeedbackBanner(
                    message: state.infoMessage!,
                    isError: false,
                    isDark: isDark,
                  ),
                ],
                const SizedBox(height: 28),
                // Primary Update Password Button (#FECE01 bg, #1A5DC9 text)
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    key: const ValueKey('update_password_button'),
                    onPressed: state.isSubmitting
                        ? null
                        : _handleUpdatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFECE01),
                      foregroundColor: const Color(0xFF1A5DC9),
                      disabledBackgroundColor: const Color(
                        0xFFFECE01,
                      ).withValues(alpha: 0.7),
                      disabledForegroundColor: const Color(0xFF1A5DC9),
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF1A5DC9),
                            ),
                          )
                        : Text(
                            'Update password',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A5DC9),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: linkColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _PasswordInputField extends StatelessWidget {
  const _PasswordInputField({
    required this.fieldKey,
    required this.controller,
    required this.obscureText,
    required this.hintText,
    required this.toggleTooltip,
    required this.textInputAction,
    required this.isDark,
    required this.focusedBorderColor,
    required this.onChanged,
    required this.onToggleVisibility,
    this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool obscureText;
  final String hintText;
  final String toggleTooltip;
  final TextInputAction textInputAction;
  final bool isDark;
  final Color focusedBorderColor;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleVisibility;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFDCE4EE);
    final fillColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);

    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: obscureText,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: hintColor,
        ),
        filled: true,
        fillColor: fillColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        suffixIcon: IconButton(
          tooltip: toggleTooltip,
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: hintColor,
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: focusedBorderColor, width: 1.8),
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.label,
    required this.met,
    required this.isDark,
  });

  final String label;
  final bool met;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = met
        ? (isDark ? Colors.white : const Color(0xFF334155))
        : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B));

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
              color: met ? const Color(0xFF1B5E20) : Colors.transparent,
              border: met
                  ? null
                  : Border.all(
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      width: 1.6,
                    ),
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
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.message,
    required this.isError,
    required this.isDark,
  });

  final String message;
  final bool isError;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isError
        ? (isDark
              ? AppColors.darkErrorBackground
              : AppColors.consentBadgeRedBackground)
        : (isDark
              ? const Color(0xFF123225)
              : AppColors.consentBadgeGreenBackground);
    final fg = isError
        ? (isDark ? AppColors.darkErrorText : AppColors.consentBadgeRedText)
        : (isDark ? AppColors.darkIconGreen : AppColors.consentBadgeGreenText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: fg,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
