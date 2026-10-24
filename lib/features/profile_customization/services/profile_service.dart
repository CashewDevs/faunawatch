import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service contract for saving and managing user profile setup data.
abstract interface class ProfileService {
  Future<bool> saveProfile({required String username, required String bio});

  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  });

  Future<bool> saveProfileBanner({String? bannerAsset, int? colorValue});
}

/// Default implementation of [ProfileService].
class FaunaProfileService implements ProfileService {
  const FaunaProfileService();

  @override
  Future<bool> saveProfile({
    required String username,
    required String bio,
  }) async {
    // Simulated async completion (ready for Supabase / backend integration)
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<bool> saveProfileBanner({String? bannerAsset, int? colorValue}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }
}

/// Riverpod provider exposing [ProfileService].
final profileServiceProvider = Provider<ProfileService>((ref) {
  return const FaunaProfileService();
});
