import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/onboarding/models/onboarding_item.dart';
import 'package:faunawatch/features/onboarding/viewmodels/onboarding_viewmodel.dart';
import 'package:faunawatch/features/onboarding/views/widgets/begin_watch_button.dart';
import 'package:faunawatch/features/onboarding/views/widgets/onboarding_artwork_placeholder.dart';
import 'package:faunawatch/features/onboarding/views/widgets/onboarding_indicator.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

/// The 3-step onboarding walkthrough view introducing core features to the user.
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    ref.read(onboardingViewModelProvider.notifier).nextPage();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onComplete() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ShellView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingViewModelProvider);
    final items = OnboardingItem.defaultItems;

    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Blue upper region with artwork placeholder
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: items.length,
                onPageChanged: (index) {
                  ref
                      .read(onboardingViewModelProvider.notifier)
                      .onPageChanged(index);
                },
                itemBuilder: (context, index) {
                  return OnboardingArtworkPlaceholder(pageIndex: index);
                },
              ),
            ),
            // White bottom presentation card
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x15000000),
                    offset: Offset(0, -6),
                    blurRadius: 20,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(28, 52, 28, 44),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header: DM Sans in Black font weight 900
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        items[onboardingState.currentPage].title,
                        key: ValueKey('title_${onboardingState.currentPage}'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: AppColors.onboardingHeaderBlack,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Subheading: DM Sans Regular
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        items[onboardingState.currentPage].description,
                        key: ValueKey('desc_${onboardingState.currentPage}'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: AppColors.onboardingSubheadingDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Yellow Indicator in #FECE01
                    OnboardingIndicator(
                      currentPage: onboardingState.currentPage,
                      pageCount: items.length,
                    ),
                    const SizedBox(height: 32),
                    // Bottom Navigation Action Area
                    SizedBox(
                      height: 64,
                      child: onboardingState.isLastPage
                          ? BeginWatchButton(onPressed: _onComplete)
                          : Align(
                              alignment: Alignment.centerRight,
                              child: Semantics(
                                container: true,
                                button: true,
                                label: 'Next',
                                child: GestureDetector(
                                  onTap: _onNext,
                                  behavior: HitTestBehavior.opaque,
                                  child: Image.asset(
                                    AppAssets.forwardButton,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
