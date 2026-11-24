import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/models/post_photo_source.dart';
import 'package:faunawatch/features/create_post/services/post_photo_picker_service.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/post_management/services/edit_post_service.dart';
import 'package:faunawatch/features/post_management/viewmodels/edit_post_viewmodel.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';
import '../../feed/fake_feed_service.dart';
import '../fake_edit_post_service.dart';

void main() {
  late FakeEditPostService service;
  late FakePhotoPicker picker;
  late FakeFeedService feed;
  late ProviderContainer container;

  final provider = editPostViewModelProvider('post-1');
  EditPostState state() => container.read(provider);
  EditPostViewModel vm() => container.read(provider.notifier);

  Future<void> open({EditablePost? post}) async {
    service = FakeEditPostService(post: post ?? samplePost());
    picker = FakePhotoPicker();
    feed = FakeFeedService(
      posts: [testPost('post-1', index: 0), testPost('other', index: 1)],
    );
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
        editPostServiceProvider.overrideWithValue(service),
        postPhotoPickerServiceProvider.overrideWithValue(picker),
        feedServiceProvider.overrideWithValue(feed),
      ],
    );
    addTearDown(container.dispose);
    // Keep the screen's ViewModel alive, as the open screen does.
    container.listen(provider, (_, _) {});
    container.listen(feedViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  test('loads the post with its caption and photos', () async {
    await open();
    expect(state().isLoading, isFalse);
    expect(state().description, 'Old caption');
    expect(state().photos, [coverPhoto, secondPhoto]);
    expect(state().canSave, isFalse);
  });

  test('a post that is gone shows nothing to edit; errors can retry', () async {
    await open();
    service.post = null;
    await vm().retry();
    expect(state().original, isNull);
    expect(state().hasError, isFalse);

    service.loadError = Exception('offline');
    await vm().retry();
    expect(state().hasError, isTrue);
    service
      ..loadError = null
      ..post = samplePost();
    await vm().retry();
    expect(state().original, isNotNull);
  });

  test('a caption change saves only the caption and keeps the post in the '
      'feed', () async {
    await open();
    final pages = feed.pageRequests.length;
    vm().editDescription('  New caption ');
    await vm().save();
    expect(service.captions, ['New caption']);
    expect(service.replaced, isEmpty);
    expect(state().outcome, EditPostOutcome.saved);
    await pumpEventQueue();
    // The feed loads again to show the new caption.
    expect(feed.pageRequests.length, pages + 1);
  });

  test(
    'removing a photo keeps the cover and sends the post for review',
    () async {
      await open();
      vm().removePhoto(1);
      await vm().save();
      expect(service.captions, isEmpty);
      final (photos, analysis) = service.replaced.single;
      expect(photos, [coverPhoto]);
      expect(analysis, isNull);
      expect(state().outcome, EditPostOutcome.sentForReview);
      // Waiting for review: out of the feed.
      expect(container.read(feedViewModelProvider).posts.map((p) => p.id), [
        'other',
      ]);
    },
  );

  test('a new cover is saved with its analysis', () async {
    await open();
    picker.picked = ['/new.jpg'];
    await vm().addPhotos(PostPhotoSource.gallery);
    expect(picker.limits, [1]);
    vm().makeCover(2);
    expect(state().cover, const NewPhoto('/new.jpg'));
    expect(state().needsAnalysis, isTrue);
    await vm().save();
    expect(service.replaced, isEmpty, reason: 'needs the analysis first');

    expect(await vm().coverForAnalysis(), '/new.jpg');
    final result = sampleIdentification(
      category: ReportCategory.potentiallyDangerousAnimal,
    );
    vm().useAnalysis(const NewPhoto('/new.jpg').key, result);
    expect(state().category, ReportCategory.potentiallyDangerousAnimal);
    await vm().save();
    final (photos, analysis) = service.replaced.single;
    expect(photos, [const NewPhoto('/new.jpg'), coverPhoto, secondPhoto]);
    expect(analysis, result);
  });

  test('an existing photo made the cover is copied for the AI', () async {
    await open();
    vm().makeCover(1);
    expect(await vm().coverForAnalysis(), '/tmp/img-2.webp');
    expect(service.copies, ['img-2']);
    expect(state().isBusy, isFalse);
  });

  test('photos over 5 MB and beyond three are left out with a note', () async {
    await open(post: samplePost(photos: const [coverPhoto]));
    picker.picked = ['/a.jpg', '/big.jpg', '/b.jpg', '/c.jpg'];
    picker.tooLarge.add('/big.jpg');
    await vm().addPhotos(PostPhotoSource.gallery);
    expect(state().photos, [
      coverPhoto,
      const NewPhoto('/a.jpg'),
      const NewPhoto('/b.jpg'),
    ]);
    expect(state().photoNotice, contains('1 photo was over 5 MB'));
    expect(state().photoNotice, contains('1 photo was left out'));

    await vm().addPhotos(PostPhotoSource.camera);
    expect(state().photoNotice, 'A post can have up to 3 photos.');
  });

  test('a failed save keeps the form and says why', () async {
    await open();
    service.error = EditPostException.notEditable;
    vm().editDescription('New caption');
    await vm().save();
    expect(state().isSaving, isFalse);
    expect(state().outcome, isNull);
    expect(state().error, EditPostException.notEditable.message);
    // Typing again clears the message.
    vm().editDescription('Newer caption');
    expect(state().error, isNull);
  });

  test('pending posts can change their photos too', () async {
    await open(post: samplePost(status: ReportStatus.pending));
    vm().removePhoto(1);
    await vm().save();
    expect(service.replaced, hasLength(1));
  });
}
