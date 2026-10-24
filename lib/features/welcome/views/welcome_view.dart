import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/auth/views/login_view.dart';
import 'package:faunawatch/features/auth/views/sign_up_view.dart';
import 'package:faunawatch/features/welcome/viewmodels/welcome_viewmodel.dart';
import 'package:faunawatch/features/welcome/views/widgets/welcome_pop_button.dart';

/// The welcome onboarding landing screen displaying the FaunaWatch brand identity,
/// tagline, and primary Log In / Sign Up entry points.
class WelcomeView extends ConsumerWidget {
  const WelcomeView({super.key});

  void _onLogin(BuildContext context, WidgetRef ref) {
    ref.read(welcomeViewModelProvider.notifier).onLoginPressed();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginView()));
  }

  void _onSignUp(BuildContext context, WidgetRef ref) {
    ref.read(welcomeViewModelProvider.notifier).onSignUpPressed();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SignUpView()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          // Patterned Background Image
          Positioned.fill(
            child: Image.asset(AppAssets.welcomeBackground, fit: BoxFit.cover),
          ),
          // Content Layout
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          children: [
                            const Spacer(flex: 7),
                            // FaunaWatch Animal Logo
                            Image.asset(
                              AppAssets.appLogo,
                              width: 120,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 14),
                            // FaunaWatch Wordmark
                            Image.asset(
                              AppAssets.appWordmark,
                              width: 270,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 14),
                            // Tagline
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
                            const Spacer(flex: 9),
                            // Log In Action Button
                            WelcomePopButton(
                              label: 'Log In',
                              backgroundColor: AppColors.welcomeLoginButton,
                              gradientColors: const [
                                Color(0xFFBBE4FD),
                                Color(0xFFA2D3F7),
                              ],
                              onPressed: () => _onLogin(context, ref),
                            ),
                            const SizedBox(height: 16),
                            // Sign Up Action Button
                            WelcomePopButton(
                              label: 'Sign Up',
                              backgroundColor: AppColors.welcomeSignUpButton,
                              gradientColors: const [
                                Color(0xFFFFE68D),
                                Color(0xFFFED255),
                              ],
                              onPressed: () => _onSignUp(context, ref),
                            ),
                            const SizedBox(height: 48),
                          ],
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
    );
  }
}
