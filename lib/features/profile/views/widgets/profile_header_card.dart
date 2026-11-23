import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';

/// Top section of the Profile screen displaying the user's chosen banner,
/// overlapping circular avatar, username, bio, optional top-left Back pill,
/// optional Message button, optional menu button, and bottom divider line.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    this.onOpenMenu,
    this.onBack,
    this.onMessage,
    this.isOpeningMessage = false,
  });

  final ProfileData profile;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onBack;
  final VoidCallback? onMessage;
  final bool isOpeningMessage;

  Widget _buildAvatar() {
    if (profile.avatarUrl != null) {
      return Image.network(
        profile.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    if (profile.customImagePath != null &&
        profile.customImagePath!.isNotEmpty &&
        !kIsWeb) {
      return Image.file(
        File(profile.customImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    if (profile.presetAvatar != null && profile.presetAvatar!.isNotEmpty) {
      return Image.asset(
        profile.presetAvatar!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Image.asset(AppAssets.avatarTweety, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    const double bannerHeight = 165.0;
    const double bottomHeight = 85.0;
    const double avatarSize = 84.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Banner area
                SizedBox(
                  width: double.infinity,
                  height: bannerHeight,
                  child:
                      profile.bannerAsset != null &&
                          profile.bannerAsset!.isNotEmpty
                      ? Image.asset(profile.bannerAsset!, fit: BoxFit.cover)
                      : Container(
                          color: profile.bannerColorValue != null
                              ? Color(profile.bannerColorValue!)
                              : AppColors.profileDefaultBanner,
                        ),
                ),
                // White bottom container with username, bio, and optional Message button
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: bottomHeight),
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(118, 12, 16, 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username.isNotEmpty
                                  ? profile.username
                                  : 'Profile',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                color: Colors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              profile.bio,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFF222222),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onMessage != null) ...[
                        const SizedBox(width: 10),
                        _ProfileMessageButton(
                          isLoading: isOpeningMessage,
                          onTap: onMessage!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Overlapping Circular Avatar
            Positioned(
              left: 20,
              top: bannerHeight - (avatarSize / 2),
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: ClipOval(child: _buildAvatar()),
              ),
            ),
            if (onBack != null)
              Positioned(
                top: 8,
                left: 12,
                child: SafeArea(
                  bottom: false,
                  child: _BannerBackButton(onTap: onBack!),
                ),
              ),
            if (onOpenMenu != null)
              Positioned(
                top: 8,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: IconButton.filledTonal(
                    tooltip: 'Profile & preferences',
                    onPressed: onOpenMenu,
                    icon: const Icon(Icons.menu_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5DC9),
                      foregroundColor: const Color(0xFFFECE01),
                      side: const BorderSide(
                        color: Color(0xFFFECE01),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Horizontal divider line
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          height: 1.5,
          color: Colors.black.withValues(alpha: 0.85),
        ),
      ],
    );
  }
}

class _BannerBackButton extends StatelessWidget {
  const _BannerBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Back',
      child: Material(
        color: scheme.surface.withValues(alpha: 0.92),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: scheme.onSurface,
                ),
                const SizedBox(width: 5),
                Text(
                  'Back',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMessageButton extends StatelessWidget {
  const _ProfileMessageButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  static const _yellowBg = Color(0xFFFECE01);
  static const _blueFg = Color(0xFF1A5DC9);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Semantics(
        button: true,
        label: 'Message',
        child: Material(
          key: const ValueKey('public_profile_message_button'),
          color: _yellowBg,
          shape: const StadiumBorder(
            side: BorderSide(color: _blueFg, width: 1.3),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _blueFg,
                      ),
                    )
                  else
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: _blueFg,
                    ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Message',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _blueFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
