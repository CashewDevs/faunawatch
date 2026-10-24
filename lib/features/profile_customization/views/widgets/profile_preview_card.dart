import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// A card previewing the user's selected profile customization:
/// banner (asset image or solid color), circular avatar with border,
/// username, and bio.
class ProfilePreviewCard extends StatelessWidget {
  const ProfilePreviewCard({
    super.key,
    required this.username,
    required this.bio,
    this.presetAvatar,
    this.customImagePath,
    this.bannerAsset,
    this.bannerColor,
  });

  final String username;
  final String bio;
  final String? presetAvatar;
  final String? customImagePath;
  final String? bannerAsset;
  final Color? bannerColor;

  Widget _buildAvatarImage() {
    if (customImagePath != null && customImagePath!.isNotEmpty && !kIsWeb) {
      return Image.file(
        File(customImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    if (presetAvatar != null && presetAvatar!.isNotEmpty) {
      return Image.asset(
        presetAvatar!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Image.asset(AppAssets.avatarPanda, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    const double bannerHeight = 110.0;
    const double bottomHeight = 64.0;
    const double avatarSize = 74.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background container with banner and white text container
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner (Image preset or solid color)
            SizedBox(
              width: double.infinity,
              height: bannerHeight,
              child: bannerAsset != null && bannerAsset!.isNotEmpty
                  ? Image.asset(bannerAsset!, fit: BoxFit.cover)
                  : Container(color: bannerColor ?? const Color(0xFFC59296)),
            ),
            // White bottom container with username and bio
            Container(
              width: double.infinity,
              height: bottomHeight,
              color: Colors.white,
              padding: const EdgeInsets.only(left: 108, right: 16),
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.isNotEmpty ? username : 'username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: AppColors.profileTitleNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bio.isNotEmpty ? bio : 'bio',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: AppColors.profileTitleNavy,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Overlapping Avatar on left side
        Positioned(
          left: 18,
          top: bannerHeight - (avatarSize / 2),
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: ClipOval(child: _buildAvatarImage()),
          ),
        ),
      ],
    );
  }
}
