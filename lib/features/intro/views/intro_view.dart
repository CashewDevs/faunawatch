import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/intro/viewmodels/intro_viewmodel.dart';
import 'package:faunawatch/features/intro/views/widgets/image_drop_shadow.dart';
import 'package:faunawatch/features/intro/views/widgets/swipe_up_indicator.dart';
import 'package:faunawatch/features/onboarding/views/onboarding_view.dart';

/// The onboarding completion screen presenting the brand identity with a slide-up
/// entry gate to the main shell.
class IntroView extends ConsumerWidget {
  const IntroView({super.key, this.animateArrow = true});

  final bool animateArrow;

  void _handleSlideUp(BuildContext context, WidgetRef ref) {
    ref.read(introViewModelProvider.notifier).onSlideUp();

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SizedBox.expand(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < -100) {
              _handleSlideUp(context, ref);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Patterned background image filling full screen
              Positioned.fill(
                child: Image.asset(
                  AppAssets.introBackground,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              // Screen content
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                          minWidth: constraints.maxWidth,
                        ),
                        child: IntrinsicHeight(
                          child: SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Spacer(flex: 5),
                                  // Mascot Logo with Y=4, Blur=4, #000000 25% Drop Shadow
                                  ImageDropShadow(
                                    imagePath: AppAssets.appLogo,
                                    width: 80,
                                    height: 80,
                                    offset: const Offset(0, 4),
                                    blurRadius: 4,
                                    shadowColor: const Color(0x40000000),
                                  ),
                                  const SizedBox(height: 18),
                                  // "Welcome to" Title
                                  Text(
                                    'Welcome to',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // FaunaWatch Wordmark with Y=4, Blur=4, #000000 25% Drop Shadow
                                  ImageDropShadow(
                                    imagePath: AppAssets.appWordmark,
                                    width: 285,
                                    offset: const Offset(0, 4),
                                    blurRadius: 4,
                                    shadowColor: const Color(0x40000000),
                                  ),
                                  const SizedBox(height: 16),
                                  // Brand Tagline
                                  Text(
                                    'Mapping life, one sighting at a time.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const Spacer(flex: 6),
                                  // Interactive swipe up area with arrow animation
                                  SwipeUpIndicator(
                                    animate: animateArrow,
                                    onSlideUp: () =>
                                        _handleSlideUp(context, ref),
                                  ),
                                  const SizedBox(height: 36),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
