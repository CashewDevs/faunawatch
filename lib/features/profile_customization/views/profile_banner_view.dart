import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_banner_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/banner_color_item.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_banner_item.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_continue_button.dart';
import 'package:faunawatch/features/profile_customization/views/profile_ready_view.dart';

/// The Profile Banner customization screen allowing users to choose a preset banner
/// (day, sunset, night) and an accent color.
class ProfileBannerView extends ConsumerWidget {
  const ProfileBannerView({super.key});

  Future<void> _handleContinue(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(profileBannerViewModelProvider.notifier)
        .submit();
    if (context.mounted && success) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ProfileReadyView()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileBannerViewModelProvider);
    final notifier = ref.read(profileBannerViewModelProvider.notifier);

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
                        // Title: Profile Banner
                        Text(
                          'Profile Banner',
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
                        // Subtitle: Choose a preset style or pick a color
                        Text(
                          'Choose a preset style or pick a color',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: AppColors.profileTitleNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Preset Banners: day.webp, sunset.webp, night.webp
                        ProfileBannerItem(
                          assetPath: AppAssets.bannerDay,
                          isSelected:
                              state.selectedBanner == AppAssets.bannerDay,
                          onTap: () =>
                              notifier.selectBanner(AppAssets.bannerDay),
                        ),
                        const SizedBox(height: 14),
                        ProfileBannerItem(
                          assetPath: AppAssets.bannerSunset,
                          isSelected:
                              state.selectedBanner == AppAssets.bannerSunset,
                          onTap: () =>
                              notifier.selectBanner(AppAssets.bannerSunset),
                        ),
                        const SizedBox(height: 14),
                        ProfileBannerItem(
                          assetPath: AppAssets.bannerNight,
                          isSelected:
                              state.selectedBanner == AppAssets.bannerNight,
                          onTap: () =>
                              notifier.selectBanner(AppAssets.bannerNight),
                        ),
                        const SizedBox(height: 48),
                        // Color Selector Container
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          color: Colors.white,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (final color in AppColors.bannerColors)
                                BannerColorItem(
                                  color: color,
                                  isSelected: state.selectedColor == color,
                                  onTap: () => notifier.selectColor(color),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 20),
                        // Continue Button
                        ProfileContinueButton(
                          isEnabled: state.isContinueEnabled,
                          isLoading: state.isSubmitting,
                          onPressed: () => _handleContinue(context, ref),
                        ),
                        const SizedBox(height: 16),
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
