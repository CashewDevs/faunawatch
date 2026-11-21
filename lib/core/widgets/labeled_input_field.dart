import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The colours of the sign-up style input boxes, for light or dark mode.
class _InputColors {
  factory _InputColors.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const _InputColors._(
          label: Colors.white,
          text: Colors.white,
          hint: Color(0xFF94A3B8),
          fill: AppColors.darkSurface,
          border: Color(0xFF475569),
          icon: Color(0xFFCBD5E1),
        )
      : const _InputColors._(
          label: AppColors.loginDarkText,
          text: AppColors.loginDarkText,
          hint: AppColors.consentMutedText,
          fill: AppColors.loginFieldBackground,
          border: AppColors.loginFieldBorder,
          icon: AppColors.loginDarkText,
        );

  const _InputColors._({
    required this.label,
    required this.text,
    required this.hint,
    required this.fill,
    required this.border,
    required this.icon,
  });

  final Color label;
  final Color text;
  final Color hint;
  final Color fill;
  final Color border;
  final Color icon;
}

/// A bold label above a rounded, filled box with an icon: the look of the
/// sign-up fields, following the app's light or dark mode. Single-line boxes
/// are pills; taller ones are rounded rectangles.
class _LabeledBox extends StatelessWidget {
  const _LabeledBox({
    required this.label,
    required this.icon,
    required this.child,
    required this.isMultiline,
    required this.enabled,
    this.helperText,
  });

  final String label;
  final IconData icon;
  final Widget child;
  final bool isMultiline;
  final bool enabled;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final colors = _InputColors.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: colors.label,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: EdgeInsets.fromLTRB(
              16,
              isMultiline ? 14 : 0,
              isMultiline ? 16 : 8,
              isMultiline ? 14 : 0,
            ),
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: BorderRadius.circular(isMultiline ? 20 : 30),
              border: Border.all(color: colors.border, width: 1.5),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: isMultiline
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: colors.icon),
                const SizedBox(width: 12),
                Expanded(child: child),
              ],
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                helperText!,
                style: GoogleFonts.dmSans(color: colors.hint, fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A sign-up style text box with a label above it.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.helperText,
    this.enabled = true,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? helperText;
  final bool enabled;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final colors = _InputColors.of(context);
    final isMultiline = maxLines > 1;
    return _LabeledBox(
      label: label,
      icon: icon,
      isMultiline: isMultiline,
      enabled: enabled,
      helperText: helperText,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        enabled: enabled,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction:
            textInputAction ??
            (isMultiline ? TextInputAction.newline : TextInputAction.next),
        style: GoogleFonts.dmSans(
          color: colors.text,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.dmSans(color: colors.hint, fontSize: 15),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: isMultiline ? 0 : 16),
        ),
      ),
    );
  }
}

/// A sign-up style dropdown with a label above it. A null [onChanged]
/// disables it.
class LabeledDropdownField<T> extends StatelessWidget {
  const LabeledDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.helperText,
  });

  final String label;
  final IconData icon;
  final T? value;

  /// Each choice and the text shown for it.
  final List<(T, String)> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final colors = _InputColors.of(context);
    final textStyle = GoogleFonts.dmSans(
      color: colors.text,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );
    return _LabeledBox(
      label: label,
      icon: icon,
      isMultiline: false,
      enabled: onChanged != null,
      helperText: helperText,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: colors.fill,
          borderRadius: BorderRadius.circular(16),
          iconEnabledColor: colors.icon,
          iconDisabledColor: colors.icon,
          hint: hintText == null
              ? null
              : Text(
                  hintText!,
                  style: GoogleFonts.dmSans(color: colors.hint, fontSize: 15),
                ),
          // A locked dropdown still shows its value.
          disabledHint: Text(
            [
                  for (final (item, text) in items)
                    if (item == value) text,
                ].firstOrNull ??
                hintText ??
                '',
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
          style: textStyle,
          onChanged: onChanged,
          items: [
            for (final (item, text) in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(text, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}
