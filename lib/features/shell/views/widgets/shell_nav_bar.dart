import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/notifications/viewmodels/notifications_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

/// Custom bottom navigation bar featuring 6 destinations (Feed, Gallery, Map,
/// Chats, Notifs, Profile) with stateful pressed/unpressed icons and active label borders.
class ShellNavBar extends ConsumerWidget {
  const ShellNavBar({
    super.key,
    required this.currentDestination,
    required this.onSelectDestination,
  });

  final ShellDestination currentDestination;
  final ValueChanged<ShellDestination> onSelectDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pictureState = ref.watch(profilePictureViewModelProvider);
    final hasUnreadNotifications = ref.watch(hasUnreadNotificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFD6E2EE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            destination: ShellDestination.feed,
            label: 'Feed',
            unpressedAsset: AppAssets.navFeedUnpressed,
            pressedAsset: AppAssets.navFeedPressed,
            isDark: isDark,
          ),
          _buildNavItem(
            destination: ShellDestination.gallery,
            label: 'Gallery',
            unpressedAsset: AppAssets.navPhotosUnpressed,
            pressedAsset: AppAssets.navPhotosPressed,
            isDark: isDark,
          ),
          _buildNavItem(
            destination: ShellDestination.map,
            label: 'Map',
            unpressedAsset: AppAssets.navMapUnpressed,
            pressedAsset: AppAssets.navMapPressed,
            isDark: isDark,
          ),
          _buildNavItem(
            destination: ShellDestination.chats,
            label: 'Chats',
            unpressedAsset: AppAssets.navChatsUnpressed,
            pressedAsset: AppAssets.navChatsPressed,
            isDark: isDark,
          ),
          _buildNavItem(
            destination: ShellDestination.notifs,
            label: 'Notifs',
            unpressedAsset: AppAssets.navNotifsUnpressed,
            pressedAsset: AppAssets.navNotifsPressed,
            hasBadge: hasUnreadNotifications,
            isDark: isDark,
          ),
          _buildProfileItem(pictureState, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required ShellDestination destination,
    required String label,
    required String unpressedAsset,
    required String pressedAsset,
    required bool isDark,
    bool hasBadge = false,
  }) {
    final isSelected = currentDestination == destination;

    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        label: label,
        selected: isSelected,
        child: GestureDetector(
          onTap: () => onSelectDestination(destination),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    isSelected ? pressedAsset : unpressedAsset,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  if (hasBadge)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        key: const Key('notifs_red_badge'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.notifsBadgeRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                            ? const Color(0xFF334155)
                            : AppColors.navActiveBackground)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? (isDark
                              ? const Color(0xFF64748B)
                              : AppColors.navActiveBorder)
                        : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: isDark
                        ? (isSelected ? Colors.white : const Color(0xFF94A3B8))
                        : AppColors.navLabelBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    ProfilePictureState pictureState, {
    required bool isDark,
  }) {
    final isSelected = currentDestination == ShellDestination.profile;

    Widget avatarImage;
    if (pictureState.customImagePath != null) {
      avatarImage = Image.file(
        File(pictureState.customImagePath!),
        width: 22,
        height: 22,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          AppAssets.avatarTweety,
          width: 22,
          height: 22,
          fit: BoxFit.cover,
        ),
      );
    } else if (pictureState.selectedPresetAvatar != null) {
      avatarImage = Image.asset(
        pictureState.selectedPresetAvatar!,
        width: 22,
        height: 22,
        fit: BoxFit.cover,
      );
    } else {
      avatarImage = Image.asset(
        AppAssets.avatarTweety,
        width: 22,
        height: 22,
        fit: BoxFit.cover,
      );
    }

    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        label: 'Profile',
        selected: isSelected,
        child: GestureDetector(
          onTap: () => onSelectDestination(ShellDestination.profile),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.navLabelBlue
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: ClipOval(child: avatarImage),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                            ? const Color(0xFF334155)
                            : AppColors.navActiveBackground)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? (isDark
                              ? const Color(0xFF64748B)
                              : AppColors.navActiveBorder)
                        : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: Text(
                  'Profile',
                  style: GoogleFonts.dmSans(
                    color: isDark
                        ? (isSelected ? Colors.white : const Color(0xFF94A3B8))
                        : AppColors.navLabelBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
