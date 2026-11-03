import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/services/create_post_service.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';

class FakeCreatePostService implements CreatePostService {
  final drafts = <PostDraft>[];
  Completer<String>? pending;
  Object? error;
  @override
  Future<String> submit(PostDraft draft) async {
    drafts.add(draft);
    if (error != null) throw error!;
    return pending == null ? 'report-1' : await pending!.future;
  }
}

class FakeLocations implements PhotoLocationService {
  GeoCoordinates? location;
  @override
  Future<GeoCoordinates?> currentLocation() async => location;
  @override
  Future<GeoCoordinates?> locationInPhoto(String path) async => location;
}

class FakePicker implements ImagePickerService {
  String? path;
  @override
  Future<String?> pickImage() async => path;
}

void main() {
  late ProviderContainer container;
  late FakeCreatePostService service;
  late FakeLocations locations;
  late FakePicker picker;
  setUp(() {
    service = FakeCreatePostService();
    locations = FakeLocations();
    picker = FakePicker();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => const Stream.empty()),
        createPostServiceProvider.overrideWithValue(service),
        photoLocationServiceProvider.overrideWithValue(locations),
        imagePickerServiceProvider.overrideWithValue(picker),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'requires category and finite in-range location before any service call',
    () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      expect(await vm.submit(), isFalse);
      vm.edit(category: ReportCategory.animalInNeed);
      for (final (lat, lng) in [
        ('', ''),
        ('NaN', '1'),
        ('91', '1'),
        ('1', '181'),
        ('Infinity', '1'),
      ]) {
        vm.edit(latitude: lat, longitude: lng);
        expect(container.read(createPostViewModelProvider).canSubmit, isFalse);
        expect(await vm.submit(), isFalse);
      }
      expect(service.drafts, isEmpty);
      vm.edit(latitude: '0', longitude: '0');
      expect(await vm.submit(), isTrue);
      expect(service.drafts.single.latitude, 0);
    },
  );

  test(
    'preserves draft on failure, hides raw errors, and permits retry',
    () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.edit(
        category: ReportCategory.otherWildlifeIncident,
        latitude: '10.3',
        longitude: '123.9',
        description: 'Bird',
      );
      service.error = StateError('private backend details');
      expect(await vm.submit(), isFalse);
      expect(container.read(createPostViewModelProvider).description, 'Bird');
      expect(
        container.read(createPostViewModelProvider).error,
        isNot(contains('private')),
      );
      service.error = null;
      expect(await vm.submit(), isTrue);
      expect(
        container.read(createPostViewModelProvider).submittedId,
        'report-1',
      );
      expect(await vm.submit(), isFalse);
      vm.reset();
      expect(container.read(createPostViewModelProvider).category, isNull);
    },
  );

  test('ignores duplicate submissions and edits while submitting', () async {
    final vm = container.read(createPostViewModelProvider.notifier);
    vm.edit(
      category: ReportCategory.animalInNeed,
      latitude: '-90',
      longitude: '180',
    );
    service.pending = Completer();
    final submission = vm.submit();
    vm.edit(latitude: '40');
    expect(await vm.submit(), isFalse);
    expect(service.drafts, hasLength(1));
    expect(container.read(createPostViewModelProvider).latitude, '-90');
    service.pending!.complete('saved');
    expect(await submission, isTrue);
  });

  test(
    'FaunaLens handoff, GPS, and manual correction keep required location',
    () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(
        const FaunaLensPhoto(
          path: 'bird.jpg',
          source: FaunaLensPhotoSource.camera,
          coordinates: GeoCoordinates(latitude: 10.3, longitude: 123.9),
        ),
      );
      expect(container.read(createPostViewModelProvider).latitude, '10.3');
      vm.edit(longitude: '124');
      expect(container.read(createPostViewModelProvider).longitude, '124');
      await vm.locate();
      expect(
        container.read(createPostViewModelProvider).error,
        contains('Enable location'),
      );
      expect(container.read(createPostViewModelProvider).longitude, '124');
      locations.location = const GeoCoordinates(latitude: 11, longitude: 125);
      await vm.locate();
      expect(container.read(createPostViewModelProvider).latitude, '11.0');
      vm.usePhoto(
        const FaunaLensPhoto(
          path: 'other.jpg',
          source: FaunaLensPhotoSource.gallery,
        ),
      );
      expect(container.read(createPostViewModelProvider).hasLocation, isFalse);
    },
  );

  test(
    'picker cancellation preserves draft and gallery GPS prefills coordinates',
    () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.edit(description: 'Bird');
      await vm.pickPhoto();
      expect(container.read(createPostViewModelProvider).description, 'Bird');
      picker.path = 'selected.jpg';
      locations.location = const GeoCoordinates(latitude: 1, longitude: 2);
      await vm.pickPhoto();
      expect(
        container.read(createPostViewModelProvider).photoPath,
        'selected.jpg',
      );
      expect(container.read(createPostViewModelProvider).hasLocation, isTrue);
    },
  );

  test(
    'schema mapping trims optional fields and uses pending moderation without AI',
    () {
      final row = const PostDraft(
        category: ReportCategory.animalInNeed,
        latitude: 10,
        longitude: 123,
        description: '  Bird  ',
      ).toRow('user');
      expect(row['description'], 'Bird');
      expect(row['user_species'], isNull);
      expect(row['status'], 'pending');
      expect(row['ai_status'], 'unavailable');
      expect(
        () => PostDraft(
          category: ReportCategory.animalInNeed,
          latitude: double.nan,
          longitude: 1,
        ).toRow('user'),
        throwsArgumentError,
      );
    },
  );
}
