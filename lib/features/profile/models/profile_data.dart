/// Immutable domain model representing a user's profile information.
class ProfileData {
  const ProfileData({
    this.username = 'tweetybird',
    this.bio = 'pls dont be inluv wt sum1 else',
    this.presetAvatar,
    this.customImagePath,
    this.bannerAsset,
    this.bannerColorValue,
  });

  final String username;
  final String bio;
  final String? presetAvatar;
  final String? customImagePath;
  final String? bannerAsset;
  final int? bannerColorValue;

  ProfileData copyWith({
    String? username,
    String? bio,
    String? presetAvatar,
    String? customImagePath,
    String? bannerAsset,
    int? bannerColorValue,
    bool clearPresetAvatar = false,
    bool clearCustomImage = false,
    bool clearBannerAsset = false,
    bool clearBannerColor = false,
  }) {
    return ProfileData(
      username: username ?? this.username,
      bio: bio ?? this.bio,
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
    );
  }
}
