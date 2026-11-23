import 'package:faunawatch/features/profile/models/profile_tag.dart';

/// Immutable domain model representing a user's profile information.
class ProfileData {
  const ProfileData({
    this.username = '',
    this.bio = '',
    this.profileTag,
    this.avatarUrl,
    this.presetAvatar,
    this.customImagePath,
    this.bannerAsset,
    this.bannerColorValue,
    this.postsPrivate = false,
  });

  final String username;
  final String bio;
  final ProfileTag? profileTag;
  final String? avatarUrl;
  final String? presetAvatar;
  final String? customImagePath;
  final String? bannerAsset;
  final int? bannerColorValue;

  /// The owner turned on Settings › Privacy › Private posts: visitors to
  /// their profile see a notice instead of their posts (the server returns
  /// none). Their posts still appear in the Feed and on the map.
  final bool postsPrivate;

  ProfileData copyWith({
    String? username,
    String? bio,
    ProfileTag? profileTag,
    bool clearProfileTag = false,
    String? presetAvatar,
    String? customImagePath,
    String? bannerAsset,
    int? bannerColorValue,
    bool? postsPrivate,
    bool clearPresetAvatar = false,
    bool clearCustomImage = false,
    bool clearBannerAsset = false,
    bool clearBannerColor = false,
  }) {
    return ProfileData(
      avatarUrl:
          clearCustomImage || presetAvatar != null || customImagePath != null
          ? null
          : avatarUrl,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      profileTag: clearProfileTag ? null : (profileTag ?? this.profileTag),
      presetAvatar: clearPresetAvatar
          ? null
          : (presetAvatar ?? this.presetAvatar),
      customImagePath: clearCustomImage
          ? null
          : (customImagePath ?? this.customImagePath),
      bannerAsset: clearBannerAsset ? null : (bannerAsset ?? this.bannerAsset),
      bannerColorValue: clearBannerColor
          ? null
          : (bannerColorValue ?? this.bannerColorValue),
      postsPrivate: postsPrivate ?? this.postsPrivate,
    );
  }
}
