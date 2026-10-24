import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/auth/viewmodels/sign_up_viewmodel.dart';
import 'package:faunawatch/features/auth/views/login_view.dart';
import 'package:faunawatch/features/auth/views/widgets/auth_text_field.dart';
import 'package:faunawatch/features/auth/views/widgets/google_sign_in_button.dart';
import 'package:faunawatch/features/auth/views/widgets/login_action_button.dart';
import 'package:faunawatch/features/profile_customization/views/profile_setup_view.dart';

/// The Sign Up screen displaying the left-aligned cloud header graphic,
/// registration credentials form, confirm password field, and social options.
class SignUpView extends ConsumerWidget {
  const SignUpView({super.key});

  Future<void> _handleSignUp(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(signUpViewModelProvider.notifier)
        .submitSignUp();
    if (context.mounted && success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ProfileSetupView()),
        (route) => false,
      );
    }
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginView()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signUpViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.loginGradientTop,
      body: Stack(
        children: [
          // Screen background gradient 0% #1A5DC9 to 100% #FFFFFF
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.loginGradientTop,
                    AppColors.loginGradientBottom,
                  ],
                ),
              ),
            ),
          ),
          // Top Branded Header with Cloud Graphic on Left
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340,
            child: Stack(
              children: [
                // Cloud graphic pinned to the top left
                Positioned(
                  top: 0,
                  left: -20,
                  bottom: 20,
                  child: Image.asset(
                    AppAssets.signUpDesign,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                // Heading text content aligned on the right
                Positioned(
                  top: 90,
                  right: 36,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Let's Get\nStarted",
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmSans(
                          color: AppColors.loginTitleYellow,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.05 * 38,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Make every\nencounter count.',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmSans(
                          color: AppColors.loginSubtitleBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // White Rounded Bottom Sheet for Input and Actions (foreground layer)
          Positioned(
            top: 263,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Email / Username Input
                    AuthTextField(
                      label: 'Email Address',
                      prefixIconPath: AppAssets.usernameIcon,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) {
                        ref
                            .read(signUpViewModelProvider.notifier)
                            .onEmailChanged(value);
                      },
                    ),
                    const SizedBox(height: 18),
                    // Password Input
                    AuthTextField(
                      label: 'Password',
                      prefixIconPath: AppAssets.passwordIcon,
                      obscureText: !state.isPasswordVisible,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) {
                        ref
                            .read(signUpViewModelProvider.notifier)
                            .onPasswordChanged(value);
                      },
                      suffixIcon: IconButton(
                        icon: Image.asset(
                          state.isPasswordVisible
                              ? AppAssets.seePasswordIcon
                              : AppAssets.hidePasswordIcon,
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                        onPressed: () {
                          ref
                              .read(signUpViewModelProvider.notifier)
                              .togglePasswordVisibility();
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Confirm Password Input
                    AuthTextField(
                      label: 'Confirm Password',
                      prefixIconPath: AppAssets.passwordIcon,
                      obscureText: !state.isConfirmPasswordVisible,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        ref
                            .read(signUpViewModelProvider.notifier)
                            .onConfirmPasswordChanged(value);
                      },
                      suffixIcon: IconButton(
                        icon: Image.asset(
                          state.isConfirmPasswordVisible
                              ? AppAssets.seePasswordIcon
                              : AppAssets.hidePasswordIcon,
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                        onPressed: () {
                          ref
                              .read(signUpViewModelProvider.notifier)
                              .toggleConfirmPasswordVisibility();
                        },
                      ),
                    ),
                    const SizedBox(height: 38),
                    // Sign Up Action Button
                    LoginActionButton(
                      label: 'Sign Up',
                      isEnabled: state.isSignUpEnabled,
                      isLoading: state.isSubmitting,
                      onPressed: () => _handleSignUp(context, ref),
                    ),
                    const SizedBox(height: 36),
                    // Divider
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: AppColors.loginDividerLine,
                            thickness: 1.5,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or continue with',
                            style: GoogleFonts.dmSans(
                              color: AppColors.loginDividerText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: AppColors.loginDividerLine,
                            thickness: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Google Sign In Button
                    Center(
                      child: GoogleSignInButton(
                        onPressed: () {
                          // Google auth placeholder
                        },
                      ),
                    ),
                    const SizedBox(height: 54),
                    // Already have an account footer
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: GoogleFonts.dmSans(
                              color: AppColors.loginDividerText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _navigateToLogin(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: Text(
                                'Log In',
                                style: GoogleFonts.dmSans(
                                  color: AppColors.loginSignUpYellowDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
