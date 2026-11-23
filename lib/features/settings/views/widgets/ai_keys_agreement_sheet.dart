import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_settings_style.dart';

/// Shows the AI Keys Agreement for [provider]. Resolves to `true` only when
/// the user ticks the box and taps "Agree & save key".
Future<bool> showAiKeysAgreementSheet(
  BuildContext context, {
  required AiProvider provider,
  required VoidCallback onReadFullAgreement,
}) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AiSettingsStyle.of(context).sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AiKeysAgreementSheet(
      provider: provider,
      onReadFullAgreement: onReadFullAgreement,
    ),
  );
  return agreed ?? false;
}

/// The complete in-app AI Keys Agreement for [provider], with a link to the
/// provider's own terms through [onOpenTerms].
Future<void> showAiKeysFullAgreement(
  BuildContext context, {
  required AiProvider provider,
  required VoidCallback onOpenTerms,
}) {
  // TODO(legal): Link the full AI Keys Agreement document once it is
  // published. Until then this shows the complete in-app agreement text.
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final style = AiSettingsStyle.of(dialogContext);
      return AlertDialog(
        backgroundColor: style.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.description_outlined, color: style.accent, size: 28),
        title: Text(
          'AI Keys Agreement',
          style: GoogleFonts.dmSans(
            color: style.title,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (_, title, body) in aiKeysAgreementPoints(
                provider,
              )) ...[
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.dmSans(
                      color: style.muted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: title,
                        style: TextStyle(
                          color: style.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: body),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: onOpenTerms,
            child: Text(
              '${provider.displayName} terms',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: style.accent,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Close',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    },
  );
}

/// The four AI Keys Agreement points, worded for [provider].
List<(IconData, String, String)> aiKeysAgreementPoints(AiProvider provider) {
  final name = provider.displayName;
  return [
    (
      Icons.attach_money_rounded,
      'You pay for usage.',
      ' Each photo you check is billed by $name to your account.',
    ),
    (
      Icons.description_outlined,
      'Their rules apply too.',
      " You agree to follow $name's own terms and usage policies.",
    ),
    (
      Icons.photo_camera_outlined,
      'Photos go to $name.',
      ' Only the photo you ask about is sent, to identify the animal.',
    ),
    (
      Icons.lock_outline_rounded,
      "You're in control.",
      ' Your key stays encrypted on this phone. Remove it anytime in '
          'Settings › AI Integration.',
    ),
  ];
}

class AiKeysAgreementSheet extends StatefulWidget {
  const AiKeysAgreementSheet({
    super.key,
    required this.provider,
    required this.onReadFullAgreement,
  });

  final AiProvider provider;
  final VoidCallback onReadFullAgreement;

  @override
  State<AiKeysAgreementSheet> createState() => _AiKeysAgreementSheetState();
}

class _AiKeysAgreementSheetState extends State<AiKeysAgreementSheet> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final style = AiSettingsStyle.of(context);
    final points = aiKeysAgreementPoints(widget.provider);

    BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
      color: style.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor ?? style.border, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: style.isDark ? 0.3 : 0.04),
          offset: const Offset(0, 3),
          blurRadius: 8,
        ),
      ],
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: style.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'AI KEYS AGREEMENT',
              style: GoogleFonts.dmSans(
                color: style.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Before we save your ${widget.provider.displayName} key',
              style: GoogleFonts.dmSans(
                color: style.title,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: cardDecoration(),
              child: Column(
                children: [
                  for (final (index, (icon, title, body))
                      in points.indexed) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: style.border,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 24, color: style.accent),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: GoogleFonts.dmSans(
                                  color: style.muted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: title,
                                    style: TextStyle(
                                      color: style.title,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: body),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: cardDecoration(
                borderColor: _agreed ? style.accent : null,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: (value) =>
                              setState(() => _agreed = value ?? false),
                          activeColor: style.accent,
                          side: BorderSide(color: style.muted, width: 1.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'I agree to the AI Keys Agreement',
                            style: GoogleFonts.dmSans(
                              color: style.title,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onReadFullAgreement,
                style: TextButton.styleFrom(
                  foregroundColor: style.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Text(
                  'Read the full AI Keys Agreement',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _agreed
                    ? () => Navigator.of(context).pop(true)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: style.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: style.accent.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Agree & save key',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: style.muted),
                child: Text(
                  'Not now',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
