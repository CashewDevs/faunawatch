import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_continue_button.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/spotter_avatar_item.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/upload_picture_button.dart';
import 'package:faunawatch/features/profile_customization/views/profile_banner_view.dart';

/// The Profile Picture customization screen allowing users to pick from spotter avatars or upload a photo.
class ProfilePictureView extends ConsumerWidget {
  const ProfilePictureView({super.key});

  Future<void> _handleContinue(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(profilePictureViewModelProvider.notifier)
        .submit();
    if (context.mounted && success) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProfileBannerView()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilePictureViewModelProvider);
    final notifier = ref.read(profilePictureViewModelProvider.notifier);

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
                        // Title: Your Profile Picture
                        Text(
                          'Your Profile Picture',
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
                        // Subtitle
                        Text(
                          'Select a spotter icon or upload a custom image.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: AppColors.profileTitleNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // 3x3 Grid of 9 Spotter Avatars
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int row = 0; row < 3; row++) ...[
                              if (row > 0) const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (int col = 0; col < 3; col++) ...[
                                    if (col > 0) const SizedBox(width: 16),
                                    () {
                                      final index = row * 3 + col;
                                      final avatarPath =
                                          AppAssets.spotterAvatars[index];
                                      final isSelected =
                                          state.selectedPresetAvatar ==
                                          avatarPath;
                                      return SpotterAvatarItem(
                                        assetPath: avatarPath,
                                        isSelected: isSelected,
                                        onTap: () => notifier
                                            .selectPresetAvatar(avatarPath),
                                      );
                                    }(),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 36),
                        // Upload Label: Upload a pic!
                        Text(
                          'Upload a pic!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: AppColors.profileTitleNavy,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Circular Upload Button
                        UploadPictureButton(
                          isSelected: state.isCustomImageSelected,
                          customImagePath: state.customImagePath,
                          onTap: () => ref
                              .read(profilePictureViewModelProvider.notifier)
                              .pickCustomImage(),
                        ),
                        const Spacer(),
                        const SizedBox(height: 20),
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
