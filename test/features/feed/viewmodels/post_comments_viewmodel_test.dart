import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/services/post_comments_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/viewmodels/post_comments_viewmodel.dart';
import 'package:faunawatch/features/feed/viewmodels/post_likes_viewmodel.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  final provider = postCommentsViewModelProvider(sampleMapPost.id);

  PostCommentsViewModel vm() => container.read(provider.notifier);
  PostCommentsState state() => container.read(provider);

  Future<void> load() async {
    container.read(provider);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    container = ProviderContainer(
      overrides: [
        profileViewModelProvider.overrideWith(_FakeProfileViewModel.new),
        imagePickerServiceProvider.overrideWithValue(_FakeImagePicker()),
      ],
    );
    addTearDown(container.dispose);
  });

  group('PostCommentsViewModel', () {
    test('loads sample comments ordered by likes', () async {
      expect(state().isLoading, isTrue);
      await load();
      expect(state().isLoading, isFalse);
      expect(state().totalCount, 6);
      final likes = state().comments.map((c) => c.likeCount).toList();
      expect(likes, [...likes]..sort((a, b) => b.compareTo(a)));
    });

    test('other posts start without comments', () async {
      final other = postCommentsViewModelProvider('sample-night-watch');
      container.read(other);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(other).comments, isEmpty);
    });

    test('adds a trimmed comment first using the profile identity', () async {
      await load();
      await container.read(profileViewModelProvider.future);
      expect(await vm().addComment('  Nice  '), isTrue);
      final comment = state().comments.first;
      expect(comment.text, 'Nice');
      expect(comment.authorName, 'spotter_one');
      expect(comment.authorAvatarAsset, 'avatar.webp');
      expect(state().totalCount, 7);
    });

    test('rejects blank comments unless a photo is attached', () async {
      await load();
      expect(await vm().addComment('   '), isFalse);
      expect(state().totalCount, 6);
      expect(await vm().addComment('', imagePath: 'photo.jpg'), isTrue);
      expect(state().comments.first.imagePath, 'photo.jpg');
    });

    test('adds replies to the parent comment', () async {
      await load();
      final parent = state().comments.last;
      await vm().addComment('A reply', parentId: parent.id);
      final updated = state().comments.last;
      expect(updated.replies.last.text, 'A reply');
      expect(updated.replies.length, parent.replies.length + 1);
      expect(state().comments.first.text, isNot('A reply'));
    });

    test('like and dislike toggle and exclude each other', () async {
      await load();
      final original = state().comments.first;
      PostComment current() => state().comments.first;

      vm().toggleLike(original.id);
      expect(current().isLiked, isTrue);
      expect(current().likeCount, original.likeCount + 1);

      vm().toggleDislike(original.id);
      expect(current().isDisliked, isTrue);
      expect(current().isLiked, isFalse);
      expect(current().likeCount, original.likeCount);

      vm().toggleLike(original.id);
      expect(current().isDisliked, isFalse);
      expect(current().likeCount, original.likeCount + 1);

      vm().toggleLike(original.id);
      expect(current().likeCount, original.likeCount);
    });

    test('reacts to nested replies', () async {
      await load();
      final reply = state().comments.first.replies.first;
      vm().toggleLike(reply.id);
      expect(state().comments.first.replies.first.isLiked, isTrue);
    });

    test('reacting does not reorder until the sort is reselected', () async {
      await load();
      final last = state().comments.last.id;
      for (var i = 0; i < 2; i++) {
        vm().toggleLike(last);
        vm().toggleLike(last);
      }
      expect(state().comments.last.id, last);

      vm().setSortOrder(CommentSortOrder.newest);
      final times = state().comments.map((c) => c.createdAt).toList();
      expect(times, [...times]..sort((a, b) => b.compareTo(a)));
    });

    test('pickImage returns the picked path and swallows failures', () async {
      expect(await vm().pickImage(), 'picked.jpg');
      container.dispose();
      container = ProviderContainer(
        overrides: [
          imagePickerServiceProvider.overrideWithValue(
            _FakeImagePicker(fails: true),
          ),
        ],
      );
      expect(await vm().pickImage(), isNull);
    });

    test('keeps the composer text when posting fails', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          postCommentsServiceProvider.overrideWithValue(_FailingService()),
          profileViewModelProvider.overrideWith(_FakeProfileViewModel.new),
        ],
      );
      await load();
      expect(await vm().addComment('Nice'), isFalse);
      expect(state().comments, isEmpty);
    });
  });

  group('PostLikesViewModel', () {
    test('toggles a post', () {
      final likes = container.read(postLikesViewModelProvider.notifier);
      likes.toggle('a');
      expect(container.read(postLikesViewModelProvider), {'a'});
      likes.toggle('a');
      expect(container.read(postLikesViewModelProvider), isEmpty);
    });
  });

  group('FeedViewModel', () {
    test('opening a post switches to For You, unknown ids are ignored', () {
      final feed = container.read(feedViewModelProvider.notifier);
      container.read(feedTabViewModelProvider.notifier).select(FeedTab.gallery);

      feed.openSamplePost('unknown');
      expect(container.read(feedViewModelProvider), isNull);
      expect(container.read(feedTabViewModelProvider), FeedTab.gallery);

      feed.openSamplePost(sampleMapPost.id);
      expect(container.read(feedViewModelProvider), same(sampleMapPost));
      expect(container.read(feedTabViewModelProvider), FeedTab.forYou);
    });
  });

  group('formatters', () {
    test('formatCommentAge', () {
      final now = DateTime(2026, 10, 30, 12);
      String age(Duration d) => formatCommentAge(now.subtract(d), now);
      expect(age(const Duration(seconds: 10)), 'now');
      expect(age(const Duration(minutes: 37)), '37m');
      expect(age(const Duration(hours: 22)), '22h');
      expect(age(const Duration(days: 3)), '3d');
      expect(age(const Duration(days: 15)), '2w');
    });

    test('formatCompactCount', () {
      expect(formatCompactCount(999), '999');
      expect(formatCompactCount(1000), '1K');
      expect(formatCompactCount(1406), '1.4K');
      expect(formatCompactCount(14500), '14.5K');
    });
  });
}

class _FakeProfileViewModel extends ProfileViewModel {
  @override
  Future<ProfileData> build() async =>
      const ProfileData(username: 'spotter_one', presetAvatar: 'avatar.webp');
}

class _FakeImagePicker implements ImagePickerService {
  _FakeImagePicker({this.fails = false});
  final bool fails;

  @override
  Future<String?> pickImage() async {
    if (fails) throw Exception('picker failed');
    return 'picked.jpg';
  }
}

class _FailingService implements PostCommentsService {
  @override
  Future<List<PostComment>> fetchComments(String postId) async => const [];

  @override
  Future<PostComment> addComment({
    required String postId,
    required String authorName,
    required String text,
    String? authorAvatarAsset,
    String? authorAvatarFilePath,
    String? authorAvatarUrl,
    String? imagePath,
  }) async => throw Exception('post failed');
}
