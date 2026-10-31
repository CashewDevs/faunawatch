import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/notifications/viewmodels/notifications_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

const double _addButtonSize = 56;

/// How far the Add post button rises above the top edge of the bar.
const double _addButtonRise = 22;
const double _notchHalfWidth = 48;
const double _notchDepth = 38;

/// Custom bottom navigation bar with Feed, Chats, Notifs, and Profile items
/// around a raised Add post button that sits in a notch at the top of the bar.
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _addButtonRise),
            child: CustomPaint(
              painter: _NotchedBarPainter(
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderColor: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFD6E2EE),
                shadowColor: Colors.black.withValues(
                  alpha: isDark ? 0.35 : 0.08,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                      destination: ShellDestination.chats,
                      label: 'Chats',
                      unpressedAsset: AppAssets.navChatsUnpressed,
                      pressedAsset: AppAssets.navChatsPressed,
                      isDark: isDark,
                    ),
                    // Keeps the items clear of the Add post button.
                    const SizedBox(width: _notchHalfWidth * 2),
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
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: _AddPostButton(
              isSelected: currentDestination == ShellDestination.addPost,
              onTap: () => onSelectDestination(ShellDestination.addPost),
            ),
          ),
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

/// Round brand-colored button for creating a post.
class _AddPostButton extends StatelessWidget {
  const _AddPostButton({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Add post',
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _addButtonSize,
          height: _addButtonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.profileButtonGradientStart,
                AppColors.profileButtonGradientEnd,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.profileButtonGradientEnd.withValues(
                  alpha: 0.45,
                ),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: AppColors.shellHeaderBlue,
            size: 36,
          ),
        ),
      ),
    );
  }
}

/// Paints the bar's rounded body with a smooth dip for the Add post button.
class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
  });

  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;

  static const double _radius = 20;

  Path _barPath(Size size) {
    final center = size.width / 2;
    return Path()
      ..moveTo(_radius, 0)
      ..lineTo(center - _notchHalfWidth, 0)
      ..cubicTo(center - 32, 0, center - 44, _notchDepth, center, _notchDepth)
      ..cubicTo(
        center + 44,
        _notchDepth,
        center + 32,
        0,
        center + _notchHalfWidth,
        0,
      )
      ..lineTo(size.width - _radius, 0)
      ..arcToPoint(
        Offset(size.width, _radius),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(size.width, size.height - _radius)
      ..arcToPoint(
        Offset(size.width - _radius, size.height),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(_radius, size.height)
      ..arcToPoint(
        Offset(0, size.height - _radius),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(0, _radius)
      ..arcToPoint(
        const Offset(_radius, 0),
        radius: const Radius.circular(_radius),
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _barPath(size);
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter oldDelegate) =>
      fillColor != oldDelegate.fillColor ||
      borderColor != oldDelegate.borderColor ||
      shadowColor != oldDelegate.shadowColor;
}
