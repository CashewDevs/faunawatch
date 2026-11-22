import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';

/// Informational screen explaining how FaunaWatch AI assessments work,
/// what confidence/severity labels mean, and AI limitations.
class AboutAiReportsView extends StatelessWidget {
  const AboutAiReportsView({super.key});

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
          'About AI Reports',
          style: GoogleFonts.dmSans(
            color: titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Container(
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
              // 1. Yellow Disclaimer Callout Card
              _CalloutCard(
                backgroundColor: isDark
                    ? const Color(0xFF332B12)
                    : const Color(0xFFFFF5CC),
                icon: Icons.auto_awesome_outlined,
                iconColor: isDark
                    ? const Color(0xFFFFD54F)
                    : const Color(0xFF5C4300),
                title: 'AI gives a first guess, not an answer',
                titleColor: isDark
                    ? const Color(0xFFFFE082)
                    : const Color(0xFF4A3500),
                body:
                    'Every AI result in FaunaWatch is a preliminary assessment. '
                    'It can be wrong, so please check it before you post.',
                bodyColor: isDark
                    ? const Color(0xFFF5E6B8)
                    : const Color(0xFF5A4510),
              ),
              const SizedBox(height: 14),

              // 2. What the AI looks at
              _SectionCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardHeading('What the AI looks at', isDark: isDark),
                    const SizedBox(height: 12),
                    _BulletItem(
                      text: 'Whether there is an animal in your photo at all.',
                      dotColor: palette.shellHeaderBlue,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _BulletItem(
                      text:
                          'Up to three possible species, never just one sure answer.',
                      dotColor: palette.shellHeaderBlue,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _BulletItem(
                      text:
                          'What you can see in the photo, such as an obvious injury.',
                      dotColor: palette.shellHeaderBlue,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _BulletItem(
                      text:
                          'Whether a guess matches the list of possible invasive species for the pilot area.',
                      dotColor: palette.shellHeaderBlue,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. What the labels mean (High, Moderate, Low)
              _SectionCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardHeading('What the labels mean', isDark: isDark),
                    const SizedBox(height: 4),
                    Text(
                      'Labels show how well the photo supports a guess. '
                      'They are not percentages.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFF1F5F9),
                    ),
                    _LabelMeaningRow(
                      label: 'High',
                      pillBackground: isDark
                          ? const Color(0xFF143524)
                          : const Color(0xFFDDF3E4),
                      pillTextColor: isDark
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFF1E6B3A),
                      description:
                          'The photo supports this guess well. Still double-check.',
                      isDark: isDark,
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFF1F5F9),
                    ),
                    _LabelMeaningRow(
                      label: 'Moderate',
                      pillBackground: isDark
                          ? const Color(0xFF3A2F12)
                          : const Color(0xFFFFF2C6),
                      pillTextColor: isDark
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFF8A5A00),
                      description:
                          'Could be right, but similar animals look alike.',
                      isDark: isDark,
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFF1F5F9),
                    ),
                    _LabelMeaningRow(
                      label: 'Low',
                      pillBackground: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEBF0F7),
                      pillTextColor: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                      description: 'A weak guess. Treat it as a hint only.',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Peach Warning Callout Card (What AI cannot do)
              _CalloutCard(
                backgroundColor: isDark
                    ? const Color(0xFF3A2018)
                    : const Color(0xFFFCE6DA),
                icon: Icons.warning_amber_rounded,
                iconColor: isDark
                    ? const Color(0xFFFFAB91)
                    : const Color(0xFF8C3B16),
                title: 'What AI cannot do',
                titleColor: isDark
                    ? const Color(0xFFFFCCBC)
                    : const Color(0xFF7A2E0E),
                body:
                    'It is not a vet, a wildlife officer or an emergency service. '
                    'It cannot confirm that an animal is invasive or healthy. '
                    'Never approach or handle an animal that may be dangerous.',
                bodyColor: isDark
                    ? const Color(0xFFF5D0C5)
                    : const Color(0xFF6E2A10),
              ),
              const SizedBox(height: 14),

              // 5. If AI is not available
              _SectionCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardHeading('If AI is not available', isDark: isDark),
                    const SizedBox(height: 8),
                    Text(
                      'Your report is still saved and posted. It shows as '
                      '"AI pending" and the result is added when the AI '
                      'service is back.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isDark
                            ? AppColors.darkTextBody
                            : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 6. Your photos and AI
              _SectionCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardHeading('Your photos and AI', isDark: isDark),
                    const SizedBox(height: 8),
                    Text(
                      'When you tap Ask AI, your photo and report details are '
                      'sent through our server to an AI service. Skip AI if '
                      'you would rather not send them.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isDark
                            ? AppColors.darkTextBody
                            : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.isDark, required this.child});

  final bool isDark;
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
      child: child,
    );
  }
}

class _CalloutCard extends StatelessWidget {
  const _CalloutCard({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.body,
    required this.bodyColor,
  });

  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String body;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: bodyColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading(this.text, {required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({
    required this.text,
    required this.dotColor,
    required this.isDark,
  });

  final String text;
  final Color dotColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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

class _LabelMeaningRow extends StatelessWidget {
  const _LabelMeaningRow({
    required this.label,
    required this.pillBackground,
    required this.pillTextColor,
    required this.description,
    required this.isDark,
  });

  final String label;
  final Color pillBackground;
  final Color pillTextColor;
  final String description;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 86,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: pillBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: pillTextColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                height: 1.35,
                color: isDark
                    ? AppColors.darkTextBody
                    : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
