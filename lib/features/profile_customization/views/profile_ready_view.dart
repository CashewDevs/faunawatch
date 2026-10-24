import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_banner_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_setup_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_preview_card.dart';
import 'package:faunawatch/features/intro/views/intro_view.dart';

/// The final profile customization screen ("You're all set!") previewing the chosen
/// banner, profile picture, username, and bio, with a drop-shadowed proceed button.
class ProfileReadyView extends ConsumerWidget {
  const ProfileReadyView({super.key});

  void _handleProceed(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const IntroView()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupState = ref.watch(profileSetupViewModelProvider);
    final pictureState = ref.watch(profilePictureViewModelProvider);
    final bannerState = ref.watch(profileBannerViewModelProvider);

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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(),
                        // Title: You're all set!
                        Text(
                          "You're all set!",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: AppColors.profileTitleNavy,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.05 * 34,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Subtitle: single line with smaller font size
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Don't worry, you can update this anytime in your profile!",
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: GoogleFonts.dmSans(
                              color: AppColors.profileTitleNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        // Profile Customization Preview Card
                        ProfilePreviewCard(
                          username: setupState.username,
                          bio: setupState.bio,
                          presetAvatar: pictureState.selectedPresetAvatar,
                          customImagePath: pictureState.customImagePath,
                          bannerAsset: bannerState.selectedBanner,
                          bannerColor: bannerState.selectedColor,
                        ),
                        const SizedBox(height: 36),
                        // Proceed Button with Drop Shadow (aligned to the right)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            button: true,
                            label: 'Proceed',
                            child: GestureDetector(
                              onTap: () => _handleProceed(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      offset: const Offset(0, 6),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  AppAssets.proceedButton,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
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
