import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';

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
    backgroundColor: Colors.white,
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
          'Profile › AI Keys.',
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

  static const _pointColors = [
    (AppColors.consentBadgeYellowBackground, AppColors.consentBadgeYellowText),
    (AppColors.consentBadgeBlueBackground, AppColors.consentBadgeBlueText),
    (AppColors.searchHeaderBackground, AppColors.consentLogoBlue),
    (AppColors.consentBadgeGreenBackground, AppColors.consentBadgeGreenText),
  ];

  @override
  Widget build(BuildContext context) {
    final points = aiKeysAgreementPoints(widget.provider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.consentCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.aiKeyAgreementTag,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'AI Keys Agreement',
                style: GoogleFonts.dmSans(
                  color: AppColors.aiKeyAgreementTagText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Before we save your ${widget.provider.displayName} key',
              style: GoogleFonts.dmSans(
                color: AppColors.consentTitleNavy,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < points.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _pointColors[i].$1,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        points[i].$1,
                        size: 18,
                        color: _pointColors[i].$2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.dmSans(
                            color: AppColors.consentBodyText,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: points[i].$2,
                              style: const TextStyle(
                                color: AppColors.consentTitleNavy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: points[i].$3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Material(
              color: AppColors.consentInfoBackground,
              borderRadius: BorderRadius.circular(10),
              child: CheckboxListTile(
                value: _agreed,
                onChanged: (value) => setState(() => _agreed = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.consentLogoBlue,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(
                  'I agree to the AI Keys Agreement',
                  style: GoogleFonts.dmSans(
                    color: AppColors.consentTitleNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: widget.onReadFullAgreement,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Read the full AI Keys Agreement',
                  style: GoogleFonts.dmSans(
                    color: AppColors.consentLinkBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.consentLinkBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PillButton(
              label: 'Agree & save key',
              onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not now',
                  style: GoogleFonts.dmSans(
                    color: AppColors.consentTitleNavy,
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
