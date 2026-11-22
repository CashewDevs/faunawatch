import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';

/// Help guide for submitting wildlife reports and a quick feedback note form.
class HelpAndFeedbackView extends StatefulWidget {
  const HelpAndFeedbackView({super.key});

  @override
  State<HelpAndFeedbackView> createState() => _HelpAndFeedbackViewState();
}

class _HelpAndFeedbackViewState extends State<HelpAndFeedbackView> {
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    FocusScope.of(context).unfocus();
    final note = _feedbackController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note before sending.')),
      );
      return;
    }
    _feedbackController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Thanks for your feedback!')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPaletteColors.of(context);

    final headerBg = isDark ? AppColors.darkSurface : Colors.white;
    final titleColor = isDark ? scheme.primary : palette.navLabelBlue;
    final backColor = isDark ? scheme.primary : palette.shellHeaderBlue;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
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
          'Help and Feedback',
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
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.25, 1.0],
              colors: isDark
                  ? [
                      palette.darkProfileGradientStart,
                      palette.darkProfileGradientEnd,
                    ]
                  : [
                      palette.profileBackgroundGradientStart,
                      palette.profileBackgroundGradientEnd,
                    ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _HelpCard(
                  isDark: isDark,
                  title: 'How to report a sighting',
                  child: Column(
                    children: [
                      _StepRow(
                        number: '1',
                        text:
                            'Tap the "+" button on the bottom bar to capture a photo or choose one from your gallery.',
                        accentColor: palette.shellHeaderBlue,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _StepRow(
                        number: '2',
                        text:
                            'Optionally run Ask AI for a preliminary species suggestion, or skip straight to the report form.',
                        accentColor: palette.shellHeaderBlue,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _StepRow(
                        number: '3',
                        text:
                            'Confirm the species, description, and approximate location, then submit your report for review.',
                        accentColor: palette.shellHeaderBlue,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _HelpCard(
                  isDark: isDark,
                  title: 'Safety reminders',
                  child: Text(
                    'Always observe wildlife from a safe distance. Never handle, '
                    'corner, or disturb nests or young animals for a photo. For '
                    'injured or dangerous animals, contact your local wildlife '
                    'office or emergency services.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark
                          ? AppColors.darkTextBody
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _HelpCard(
                  isDark: isDark,
                  title: 'Send us a note',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Spotted a bug or have an idea to improve FaunaWatch? '
                        'Let us know below.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('feedback_note_field'),
                        controller: _feedbackController,
                        maxLines: 4,
                        maxLength: 500,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write your feedback here...',
                          hintStyle: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: palette.shellHeaderBlue,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _submitFeedback,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFECE01),
                            foregroundColor: const Color(0xFF1A5DC9),
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Send feedback',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.isDark,
    required this.title,
    required this.child,
  });

  final bool isDark;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
    required this.accentColor,
    required this.isDark,
  });

  final String number;
  final String text;
  final Color accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? AppColors.darkTextBody : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
