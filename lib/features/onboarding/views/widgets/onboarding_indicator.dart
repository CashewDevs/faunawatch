import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Horizontal pill page indicator for onboarding walkthrough.
///
/// Highlights the active page with #FECE01 in an elongated pill, while
/// inactive indicators appear as smaller rounded rectangles.
class OnboardingIndicator extends StatelessWidget {
  const OnboardingIndicator({
    super.key,
    required this.currentPage,
    this.pageCount = 3,
  });

  final int currentPage;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 34 : 20,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.onboardingIndicatorActive
                : AppColors.onboardingIndicatorInactive,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
