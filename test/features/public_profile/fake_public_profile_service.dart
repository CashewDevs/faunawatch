import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';

FeedPost publicPost(
  String id, {
  String authorId = 'other',
  ReportCategory category = ReportCategory.animalInNeed,
  int day = 20,
}) => FeedPost(
  id: id,
  title: 'Sighting $id',
  authorId: authorId,
  authorName: 'Forest Ranger',
  authorAvatarAsset: AppAssets.avatarPanda,
  category: category,
  categoryLabel: category.label,
  createdAt: DateTime.utc(2026, 11, day),
  feedAt: DateTime.utc(2026, 11, day, 12),
);

class FakePublicProfileService implements PublicProfileService {
  ProfileData? profile = const ProfileData(
    username: 'Forest Ranger',
    presetAvatar: AppAssets.avatarPanda,
    bannerAsset: AppAssets.bannerDay,
  );
  List<FeedPost> posts = [];
  Object? profileError, postsError;
  final profileRequests = <String>[];
  final postRequests =
      <({String userId, FeedPost? before, ReportCategory? category})>[];
  Future<List<FeedPost>> Function(String, FeedPost?, ReportCategory?)? onPosts;
  Future<ProfileData?> Function(String)? onProfile;

  @override
  Future<ProfileData?> fetchProfile(String userId) async {
    profileRequests.add(userId);
    if (profileError != null) throw profileError!;
    return onProfile != null ? await onProfile!(userId) : profile;
  }

  @override
  Future<List<FeedPost>> fetchPosts(
    String userId, {
    FeedPost? before,
    ReportCategory? category,
  }) async {
    postRequests.add((userId: userId, before: before, category: category));
    if (postsError != null) throw postsError!;
    if (onPosts != null) return onPosts!(userId, before, category);
    return posts;
  }
}
