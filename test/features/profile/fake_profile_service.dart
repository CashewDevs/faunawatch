import 'package:faunawatch/features/profile_customization/services/profile_service.dart';

class FakeProfileService implements ProfileService {
  String? savedUsername;
  String? savedBio;
  String? savedPresetAvatar;
  String? savedCustomImagePath;
  String? savedBanner;
  int? savedColor;
  bool succeeds = true;
  bool throwsOnSave = false;

  @override
  Future<bool> saveProfileBanner({String? bannerAsset, int? colorValue}) async {
    if (throwsOnSave) throw StateError('Unavailable');
    savedBanner = bannerAsset;
    savedColor = colorValue;
    return succeeds;
  }

  @override
  Future<bool> saveProfile({
    required String username,
    required String bio,
  }) async {
    if (throwsOnSave) throw StateError('Unavailable');
    savedUsername = username;
    savedBio = bio;
    return succeeds;
  }

  @override
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  }) async {
    if (throwsOnSave) throw StateError('Unavailable');
    savedPresetAvatar = presetAvatar;
    savedCustomImagePath = customImagePath;
    return succeeds;
  }
}
