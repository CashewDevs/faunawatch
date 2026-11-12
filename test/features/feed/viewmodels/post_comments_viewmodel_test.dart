import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/viewmodels/post_comments_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_feed_service.dart';

void main() {
  late FakeFeedService service;
  late ProviderContainer container;
  final provider = postCommentsViewModelProvider('p0');

  PostCommentsState state() => container.read(provider);
  PostCommentsViewModel vm() => container.read(provider.notifier);
  int count() => container.read(feedViewModelProvider).posts.first.commentCount;

  /// Opens the feed (so the post's count exists) and the comments.
  Future<void> open() async {
    container.read(feedViewModelProvider);
    await pumpEventQueue();
    container.listen(provider, (_, _) {});
    await pumpEventQueue();
  }

  setUp(() {
    service = FakeFeedService(
      posts: [testPost('p0', commentCount: 2)],
      comments: [
        testComment('c2', text: 'Newest', authorName: 'bird_notes'),
        testComment('c1', text: 'Older'),
      ],
    );
    container = ProviderContainer(
      overrides: [feedServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
  });

  group('PostCommentsViewModel', () {
    test(
      'loads the comments of the post as the service returns them',
      () async {
        container.listen(provider, (_, _) {});
        expect(state().isLoading, isTrue);
        await pumpEventQueue();
        expect(state().isLoading, isFalse);
        expect(state().hasError, isFalse);
        expect(state().comments.map((c) => c.text), ['Newest', 'Older']);
      },
    );

    test('an empty post has no comments and no error', () async {
      service.comments = [];
      await open();
      expect(state().comments, isEmpty);
      expect(state().hasError, isFalse);
    });

    test('a failed load shows an error that Retry can clear', () async {
      service.commentsError = Exception('offline');
      await open();
      expect(state().hasError, isTrue);
      expect(state().isLoading, isFalse);

      service.commentsError = null;
      await vm().load();
      expect(state().hasError, isFalse);
      expect(state().comments, hasLength(2));
    });

    test('makes the post count match the loaded comments', () async {
      service.comments = [testComment('c1')];
      await open();
      expect(count(), 1);
    });

    test('adds a trimmed comment first and counts it on the post', () async {
      await open();
      expect(await vm().addComment('  Nice  '), isTrue);
      expect(service.added, ['Nice']);
      expect(state().comments.first.text, 'Nice');
      expect(state().comments.first.authorName, 'me');
      expect(state().comments, hasLength(3));
      expect(state().isSending, isFalse);
      expect(state().sendError, isNull);
      expect(count(), 3);
    });

    test('ignores blank text', () async {
      await open();
      expect(await vm().addComment('   '), isFalse);
      expect(service.added, isEmpty);
    });

    test('a failed post keeps the list, reports it and can retry', () async {
      await open();
      service.addError = Exception('suspended');
      expect(await vm().addComment('Hello'), isFalse);
      expect(state().comments, hasLength(2));
      expect(state().isSending, isFalse);
      expect(
        state().sendError,
        'Could not post your comment. Please try again.',
      );
      expect(count(), 2);

      service.addError = null;
      expect(await vm().addComment('Hello'), isTrue);
      expect(state().sendError, isNull);
      expect(state().comments, hasLength(3));
    });

    test('a refused comment explains why', () async {
      await open();
      service.addError = const FormatException('Too long.');
      expect(await vm().addComment('Hello'), isFalse);
      expect(state().sendError, 'Too long.');
      vm().clearSendError();
      expect(state().sendError, isNull);
    });

    test('comments of other posts are separate', () async {
      await open();
      final other = postCommentsViewModelProvider('p1');
      container.listen(other, (_, _) {});
      expect(container.read(other).isLoading, isTrue);
    });
  });

  test('comment limits', () {
    expect(PostComment.maxLength, 1000);
    expect(FeedService.commentLimit, 100);
  });
}
