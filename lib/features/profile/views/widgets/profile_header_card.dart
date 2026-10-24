import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';

/// Top section of the Profile screen displaying the user's chosen banner,
/// overlapping circular avatar, username, bio, and bottom divider line.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({super.key, required this.profile});

  final ProfileData profile;

  Widget _buildAvatar() {
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
                // White bottom container with username and bio
                Container(
                  width: double.infinity,
                  height: bottomHeight,
                  color: Colors.white,
                  padding: const EdgeInsets.only(left: 118, right: 20),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.username.isNotEmpty
                            ? profile.username
                            : 'tweetybird',
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
                        profile.bio.isNotEmpty
                            ? profile.bio
                            : 'pls dont be inluv wt sum1 else',
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
