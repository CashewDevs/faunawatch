import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';

/// Contract for persistent profile storage and authentication teardown.
abstract interface class ProfileStorageService {
  Future<ProfileData> loadProfile();
  Future<bool> saveProfile(ProfileData data);
  Future<bool> signOut();
}

/// In-memory/default implementation of [ProfileStorageService].
class FaunaProfileStorageService implements ProfileStorageService {
  const FaunaProfileStorageService();

  @override
  Future<ProfileData> loadProfile() async {
    return const ProfileData();
  }

  @override
  Future<bool> saveProfile(ProfileData data) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return true;
  }

  @override
  Future<bool> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }
}

/// Riverpod provider exposing [ProfileStorageService].
final profileStorageServiceProvider = Provider<ProfileStorageService>((ref) {
  return const FaunaProfileStorageService();
});
