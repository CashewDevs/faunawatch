import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_tag_badge.dart';

/// Top section of the Profile screen displaying the user's chosen banner,
/// overlapping circular avatar with username and bio to its right, optional
/// Back and menu buttons, a Message action beside the name when space allows,
/// and divider.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    this.onOpenMenu,
    this.onBack,
    this.onMessage,
    this.onManageTag,
    this.isOpeningMessage = false,
  });

  final ProfileData profile;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onBack;
  final VoidCallback? onMessage;
  final VoidCallback? onManageTag;
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
    const double avatarSize = 104.0;
    const double avatarOverlap = 36.0;
    const double nameFontSize = 22.0;
    final scheme = Theme.of(context).colorScheme;
    final hasBio = profile.bio.trim().isNotEmpty;

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
                // Keep the name and bio together to the right of the avatar.
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: avatarSize - avatarOverlap + 18,
                  ),
                  color: scheme.surface,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final messageButton = onMessage == null
                          ? null
                          : _ProfileMessageButton(
                              isLoading: isOpeningMessage,
                              onTap: onMessage!,
                            );
                      // Reserve readable name space alongside the actual button
                      // width. Large text or narrow screens keep the action below.
                      final minimumNameWidth =
                          MediaQuery.textScalerOf(context).scale(nameFontSize) *
                          3;
                      final inlineMessage =
                          messageButton != null &&
                          constraints.maxWidth - avatarSize - 18 >=
                              minimumNameWidth +
                                  12 +
                                  _ProfileMessageButton.preferredWidth(context);
                      final name = Text(
                        profile.username.isNotEmpty
                            ? profile.username
                            : 'Profile',
                        style: GoogleFonts.dmSans(
                          color: scheme.onSurface,
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      );

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: avatarSize - avatarOverlap - 18,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: avatarSize + 18),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (inlineMessage)
                                        Row(
                                          children: [
                                            Expanded(child: name),
                                            const SizedBox(width: 12),
                                            messageButton,
                                          ],
                                        )
                                      else
                                        name,
                                      if (hasBio) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          profile.bio,
                                          style: GoogleFonts.dmSans(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            fontStyle: FontStyle.italic,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                      if (profile.profileTag != null) ...[
                                        const SizedBox(height: 8),
                                        ProfileTagBadge(
                                          tag: profile.profileTag!,
                                          onTap: onManageTag,
                                        ),
                                      ] else if (onManageTag != null)
                                        TextButton(
                                          key: const ValueKey(
                                            'add_profile_tag',
                                          ),
                                          onPressed: onManageTag,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 44),
                                            alignment: Alignment.centerLeft,
                                          ),
                                          child: const Text('Add profile tag'),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (messageButton != null && !inlineMessage) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: messageButton,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            // Overlapping Circular Avatar
            Positioned(
              left: 20,
              top: bannerHeight - avatarOverlap,
              child: SizedBox(
                key: const ValueKey('profile_header_avatar'),
                width: avatarSize,
                height: avatarSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(child: _buildAvatar()),
                  ),
                ),
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
        Divider(
          height: 24,
          thickness: 1,
          indent: 20,
          endIndent: 20,
          color: scheme.outlineVariant,
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
  static const _maxWidth = 180.0;
  static const _iconSize = 16.0;
  static const _labelGap = 6.0;
  static const _horizontalPadding = 8.0;

  static TextStyle get _labelStyle => GoogleFonts.dmSans(
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
    color: _blueFg,
  );

  static double preferredWidth(BuildContext context) {
    final label = TextPainter(
      text: TextSpan(text: 'Message', style: _labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = label.width + _iconSize + _labelGap + _horizontalPadding * 2;
    label.dispose();
    return width.clamp(0, _maxWidth).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: _maxWidth),
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
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: _iconSize,
                      height: _iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _blueFg,
                      ),
                    )
                  else
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: _iconSize,
                      color: _blueFg,
                    ),
                  const SizedBox(width: _labelGap),
                  Flexible(
                    child: Text(
                      'Message',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle,
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
