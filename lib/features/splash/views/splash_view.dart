import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/splash/viewmodels/splash_viewmodel.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';

/// Placeholder splash screen that simulates initial app launch before transitioning
/// to the [WelcomeView].
class SplashView extends ConsumerStatefulWidget {
  const SplashView({
    super.key,
    this.initializationDelay = const Duration(milliseconds: 1500),
    this.autoNavigate = true,
  });

  final Duration initializationDelay;
  final bool autoNavigate;

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  @override
  void initState() {
    super.initState();
    if (widget.autoNavigate) {
      _startInitialization();
    }
  }

  Future<void> _startInitialization() async {
    await ref
        .read(splashViewModelProvider.notifier)
        .initializeApp(delay: widget.initializationDelay);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const WelcomeView(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.welcomeBackgroundTone,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.appLogo,
              width: 110,
              height: 110,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              'FaunaWatch',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Splash Screen Placeholder',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
