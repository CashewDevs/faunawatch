import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_setup_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/views/profile_picture_view.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_continue_button.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_input_field.dart';

/// The first screen in the profile customization group asking for username and bio.
class ProfileSetupView extends ConsumerWidget {
  const ProfileSetupView({super.key});

  Future<void> _handleContinue(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(profileSetupViewModelProvider.notifier)
        .submit();
    if (context.mounted && success) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProfilePictureView()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileSetupViewModelProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.profileGradientTop,
              AppColors.profileGradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(),
                        // Top Illustration
                        Center(
                          child: Image.asset(
                            AppAssets.whoIcon,
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Heading: What should we call you?
                        Text(
                          'What should we\ncall you?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: AppColors.profileTitleNavy,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.05 * 34,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // First Input: Username
                        ProfileInputField(
                          maxLength: ProfileSetupState.maxUsernameLength,
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            ref
                                .read(profileSetupViewModelProvider.notifier)
                                .onUsernameChanged(value);
                          },
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Text(
                              '${state.username.length}/${ProfileSetupState.maxUsernameLength} characters',
                              style: GoogleFonts.dmSans(
                                color: AppColors.profileCounterText,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Label: Add a Bio!
                        Text(
                          'Add a Bio!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: AppColors.profileTitleNavy,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Second Input: Bio
                        ProfileInputField(
                          maxLength: ProfileSetupState.maxBioLength,
                          textInputAction: TextInputAction.done,
                          onChanged: (value) {
                            ref
                                .read(profileSetupViewModelProvider.notifier)
                                .onBioChanged(value);
                          },
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Text(
                              '${state.bio.length}/${ProfileSetupState.maxBioLength} characters',
                              style: GoogleFonts.dmSans(
                                color: AppColors.profileCounterText,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        // Continue Button
                        ProfileContinueButton(
                          isEnabled: state.isContinueEnabled,
                          isLoading: state.isSubmitting,
                          onPressed: () => _handleContinue(context, ref),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
