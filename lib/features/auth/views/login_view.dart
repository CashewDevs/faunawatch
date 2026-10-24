import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/auth/viewmodels/login_viewmodel.dart';
import 'package:faunawatch/features/auth/views/sign_up_view.dart';
import 'package:faunawatch/features/auth/views/widgets/auth_text_field.dart';
import 'package:faunawatch/features/auth/views/widgets/google_sign_in_button.dart';
import 'package:faunawatch/features/auth/views/widgets/login_action_button.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

/// The Login screen displaying the cloud-themed header, credentials form,
/// responsive Log In action button, and third-party authentication.
class LoginView extends ConsumerWidget {
  const LoginView({super.key});

  Future<void> _handleLogin(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(loginViewModelProvider.notifier)
        .submitLogin();
    if (context.mounted && success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ShellView()),
        (route) => false,
      );
    }
  }

  void _navigateToSignUp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SignUpView()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginViewModelProvider);

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
          // Top Branded Header with Cloud Graphic
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340,
            child: Stack(
              children: [
                // Cloud graphic pinned to the top right
                Positioned(
                  top: 0,
                  right: -20,
                  bottom: 20,
                  child: Image.asset(
                    AppAssets.loginDesign,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
                // Welcome text content on the left
                Positioned(
                  top: 90,
                  left: 36,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome\nBack!',
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
                        'Ready to resume\nthe watch?',
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
                            .read(loginViewModelProvider.notifier)
                            .onEmailChanged(value);
                      },
                    ),
                    const SizedBox(height: 18),
                    // Password Input
                    AuthTextField(
                      label: 'Password',
                      prefixIconPath: AppAssets.passwordIcon,
                      obscureText: !state.isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        ref
                            .read(loginViewModelProvider.notifier)
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
                              .read(loginViewModelProvider.notifier)
                              .togglePasswordVisibility();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          // Forgot password flow
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.dmSans(
                            color: AppColors.loginForgotPasswordBlue,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 38),
                    // Log In Action Button
                    LoginActionButton(
                      isEnabled: state.isLoginEnabled,
                      isLoading: state.isSubmitting,
                      onPressed: () => _handleLogin(context, ref),
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
                    // Don't have an account footer
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account yet? ",
                            style: GoogleFonts.dmSans(
                              color: AppColors.loginDividerText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _navigateToSignUp(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: Text(
                                'Sign Up',
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
