import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean placeholder reserved for artwork or illustrations in the blue top region
/// of each onboarding page.
class OnboardingArtworkPlaceholder extends StatelessWidget {
  const OnboardingArtworkPlaceholder({super.key, required this.pageIndex});

  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              'Artwork Placeholder',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
